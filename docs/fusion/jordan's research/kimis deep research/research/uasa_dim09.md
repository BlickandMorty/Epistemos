# Dimension 09: Benchmark Intelligence & SAE Feature Fingerprinting

## Research Report: Using SAE Features to Analyze, Fingerprint, and Optimize AI Benchmarks

---

## Executive Summary

This research dimension investigates whether Sparse Autoencoder (SAE) features can serve as a representation-level proxy for benchmark redundancy detection, capability coverage analysis, and evaluation optimization without executing models. The central finding is that **SAE feature overlap strongly correlates with performance-based redundancy** (Spearman rho ≈ 0.85) [^5^], enabling evaluation-free benchmark curation. Key mathematical formulations for feature redundancy, coverage curves, and asymmetric overlap have been established by Qwen-Scope [^5^]. Feature-based capability estimation has been demonstrated across 17 benchmarks spanning general knowledge, mathematics, coding, multilingual understanding, and in-context reasoning. Furthermore, **feature gaps can directly guide targeted training data synthesis**, with FAC Synthesis achieving comparable performance to MAGPIE using only 2,000 synthetic samples versus MAGPIE's 150x more data [^551^].

---

## 1. Qwen-Scope: The Foundational Framework for SAE-Based Benchmark Analysis

### 1.1 Overview and Architecture

Claim: Qwen-Scope is an open-source suite of SAEs built on the Qwen model family, comprising 14 groups of SAEs across 7 model variants from Qwen3 and Qwen3.5 series, covering both dense and mixture-of-expert architectures [^5^].
Source: Qwen-Scope: Turning Sparse Features into Development Tools for Large Language Models
URL: https://qianwen-res.oss-accelerate.aliyuncs.com/qwen-scope/Qwen_Scope.pdf
Date: 2026-04-30
Excerpt: "We introduce Qwen-Scope, an open-source suite of SAEs built on the Qwen model family, comprising 14 groups of SAEs across 7 model variants from the Qwen3 and Qwen3.5 series, covering both dense and mixture-of-expert architectures... We show that SAEs can go beyond post-hoc analysis to serve as practical interfaces for model development along four directions: (i) inference-time steering, (ii) evaluation analysis, where activated SAE features provide a representation-level proxy for benchmark redundancy and capability coverage, (iii) data-centric workflows... and (iv) post-training optimization."
Context: This is the primary source establishing SAE-based benchmark analysis as a practical methodology.
Confidence: high

### 1.2 SAE Feature Extraction Framework

The mathematical formulation of feature extraction from benchmarks is defined as follows:

For a benchmark D = {x1, x2, ..., xN}, the active feature set of sample xi is:

**F(xi) = {j ∈ {1, ..., D} : zj(xi) > 0}** (Equation 2) [^5^]

where zj(xi) is the j-th component of the SAE latent representation extracted at the last token position, incorporating the Top-k ReLU activation.

The feature footprint of the entire benchmark is:

**F(D) = ∪_{i=1}^N F(xi)** (Equation 3) [^5^]

Claim: The feature footprint of a benchmark encodes what capabilities it probes, enabling representation-level analysis without model execution [^5^].
Source: Qwen-Scope
URL: https://qianwen-res.oss-accelerate.aliyuncs.com/qwen-scope/Qwen_Scope.pdf
Date: 2026-04-30
Excerpt: "The set of features activated by a benchmark thus constitutes a compact fingerprint of what it probes. A benchmark is redundant if many samples activate the same features (coverage saturates early); two benchmarks are similar if they activate largely overlapping feature sets."
Context: Core mathematical foundation for feature-based benchmark analysis.
Confidence: high

---

## 2. Benchmark Redundancy Detection via SAE Features

### 2.1 Performance-Based Redundancy (Ground Truth)

To establish a ground truth for redundancy measurement, Qwen-Scope defines performance-based redundancy using Kendall's tau rank correlation:

**τ(S, D) = τ(p, p̂(S))** (Equation 4) [^5^]

where p ∈ R^M is the vector of model accuracies on the full benchmark D, and p̂(S) is the corresponding vector on subset S.

The expected Kendall's tau at subset size n is:

**τn = E_{S⊆D, |S|=n}[τ(S, D)]** (Equation 5) [^5^]

The redundancy scalar is the area under the τn curve:

**R(D) = (1/N) Σ_{n=1}^N τn** (Equation 6) [^5^]

Claim: Computing R(D) requires evaluating all M models on the full benchmark, demanding O(M × N) forward passes—prohibitively expensive for large-scale benchmark curation [^5^].
Source: Qwen-Scope
URL: https://qianwen-res.oss-accelerate.aliyuncs.com/qwen-scope/Qwen_Scope.pdf
Date: 2026-04-30
Excerpt: "The direct approach — evaluating a panel of M models on every benchmark and subset — requires O(M × N) forward passes and is prohibitively expensive for large-scale benchmark curation."
Context: Establishes the computational motivation for SAE-based alternatives.
Confidence: high

### 2.2 SAE Feature-Based Redundancy (Evaluation-Free Proxy)

The key innovation is replacing rank-correlation with feature-coverage curves:

**cn = E_{S⊆D, |S|=n}[|F(S)| / |F(D)|]** (Equation 7) [^5^]

The feature redundancy metric combines coverage AUC with a growth-rate correction:

**R̂(D) = AUC(cn) · N / |F(D)| = (Σ_{n=1}^N cn) / |F(D)|** (Equation 9) [^5^]

This metric is high when: (i) feature coverage saturates quickly (high AUC), AND (ii) the feature growth rate is slow relative to sample count (high N/|F(D)|).

Claim: The Spearman rank correlation between performance-based redundancy R(D) and feature redundancy R̂(D) across 17 benchmarks is ρ ≈ 0.85, suggesting feature redundancy serves as a reasonable evaluation-free proxy [^5^].
Source: Qwen-Scope
URL: https://qianwen-res.oss-accelerate.aliyuncs.com/qwen-scope/Qwen_Scope.pdf
Date: 2026-04-30
Excerpt: "The Spearman rank correlation between R(D) and R̂(D) across 17 benchmarks is ρ ≈ 0.85 (Figure 5), suggesting that feature redundancy may serve as a reasonable evaluation-free proxy for performance-based redundancy."
Context: This is the central validation result showing SAE features can predict benchmark redundancy without running models.
Confidence: high

### 2.3 Redundancy Findings Across Benchmarks

Key observations from the 17-benchmark analysis [^5^]:

- **GSM8K (1,319 samples) is more redundant than MMLU-Redux (3,000 samples)**: positioned upper right in redundancy plots, indicating inherent structural redundancy in elementary math problems
- **SuperGPQA (26,529 questions) exhibits relatively low redundancy**: large absolute size does not imply redundancy
- **High redundancy does not imply low benchmark quality**: redundancy may be desirable to reduce evaluation variance
- For benchmarks with high feature redundancy, only a small number of samples suffice to preserve model rankings
- For benchmarks with low redundancy, more samples—or new evaluation data—may be needed

---

## 3. Inter-Benchmark Similarity and Capability Overlap

### 3.1 Asymmetric Feature Overlap

The asymmetric feature overlap reveals containment relationships between benchmarks:

**overlap(D1, D2) = |F(D1) ∩ F(D2)| / |F(D1)|** (Equation 10) [^5^]

Key findings from the feature overlap matrix [^5^]:

| Benchmark Pair | Asymmetric Overlap | Interpretation |
|---------------|-------------------|----------------|
| GSM8K → MATH | 0.63 | 63% of GSM8K features are in MATH |
| MATH → GSM8K | 0.10 | Only 10% of MATH features are in GSM8K |
| EvalPlus ↔ MBPP | 0.35-0.53 | Code benchmarks form a tight cluster |
| MMLU-Pro ↔ TheoremQA | 0.56-0.68 | Broad knowledge subsumes specialized |
| MATH ↔ EvalPlus | 0.32 | Math and code share some features |

Claim: overlap(GSM8K, MATH) = 0.63 while overlap(MATH, GSM8K) = 0.10, reflecting that elementary math capabilities are largely subsumed by competition math but not vice versa [^5^].
Source: Qwen-Scope
URL: https://qianwen-res.oss-accelerate.aliyuncs.com/qwen-scope/Qwen_Scope.pdf
Date: 2026-04-30
Excerpt: "For instance, overlap(GSM8K, MATH) = 0.63 while overlap(MATH, GSM8K) = 0.10 (Figure 6), reflecting that elementary math capabilities are largely subsumed by competition math but not vice versa: MATH probes a much broader set of features that GSM8K does not touch."
Context: Demonstrates asymmetric containment relationships discoverable without model execution.
Confidence: high

### 3.2 Feature Overlap Predicts Performance Correlation

After controlling for general ability (partialing out MMLU as a proxy), the partial Pearson correlation between feature overlap and performance correlation improves to **75.5%** [^5^].

Claim: Feature overlap captures benchmark-specific capability similarity beyond general model quality, with partial Pearson correlation of 75.5% after controlling for MMLU [^5^].
Source: Qwen-Scope
URL: https://qianwen-res.oss-accelerate.aliyuncs.com/qwen-scope/Qwen_Scope.pdf
Date: 2026-04-30
Excerpt: "After this correction, the partial Pearson correlation improves to 75.5% (Table 2), providing evidence that feature overlap captures benchmark-specific capability similarity beyond general model quality."
Context: Strong evidence that SAE feature overlap can predict whether two benchmarks measure distinct capabilities.
Confidence: high

---

## 4. Sparse Autoencoder Feature Geometry and Structure

### 4.1 Meso-Scale Modular Structure ("Brain Lobes")

Claim: SAE features exhibit spatial modularity—features that co-occur functionally tend to cluster geometrically in activation space, with code/math features forming distinct "lobes" [^475^].
Source: The Geometry of Concepts: Sparse Autoencoder Feature Structure
URL: https://pmc.ncbi.nlm.nih.gov/articles/PMC12025678/
Date: 2025-03-24
Excerpt: "Features which fire primarily on math and code documents tend to cluster together spatially... A 2-lobe partition is seen to break the point cloud into roughly equal parts, active on code/math documents and English language documents, respectively."
Context: Establishes that SAE feature geometry is not random but organized into functional modules.
Confidence: high

The phi coefficient for co-occurrence affinity was found to best predict spatial structure. Mutual information between functional clusters (from co-occurrence) and geometric clusters (from cosine similarity) ruled out the null hypothesis at **954 standard deviations** [^475^].

### 4.2 Feature Distribution Across Layers

Claim: Feature activations tend to peak at specific layers, with features at early layers more spread across groups, and larger models having features more spread across layers [^473^].
Source: Group-SAE: Efficient Training of Sparse Autoencoders
URL: https://aclanthology.org/2025.emnlp-main.942.pdf
Date: Unknown (EMNLP 2025)
Excerpt: "Features activating for the first and last layers of a given group tend to be more specific for that layers... Bigger models tend to have features more spread across the layers of a given group with respect to smaller models."
Context: Layer-wise analysis is critical for benchmark fingerprinting—different capabilities may be encoded at different depths.
Confidence: high

### 4.3 Mathematical Formulation of TopK SAE

The TopK SAE architecture is central to modern SAE-based analysis [^553^] [^554^] [^556^]:

**Encoding:**
1. Center: x_centered = x − b_pre
2. Expand: f = ReLU(W_enc · x_centered + b_enc)
3. Sparsify: z = TopK(f, k)

**Decoding:**
x̂ = W_dec · z + b_dec + b_pre

**Loss (TopK eliminates L1 penalty):**
L = ||x − x̂||²_2

Claim: TopK SAEs provide direct control over L0 sparsity, eliminate activation shrinkage from L1 penalties, and consistently outperform standard ReLU autoencoders on reconstruction-sparsity tradeoffs [^554^].
Source: Evaluation of Sparse Autoencoder-based Refusal Features
URL: https://repositum.tuwien.at/bitstream/20.500.12708/220332/1/Kerl%20Tilman%20-%202025%20-%20Evaluation%20of%20Sparse%20Autoencoder-based%20Refusal%20Features%20in...
Date: 2025
Excerpt: "A key advantage of this formulation is the elimination of the L1 penalty from the loss function... Top-k SAEs consistently outperform standard ReLU autoencoders on reconstruction-sparsity, this advantage grows as model size increases."
Context: TopK SAEs are the dominant architecture for interpretability work.
Confidence: high

---

## 5. Feature-Based Capability Estimation Without Model Execution

### 5.1 Core Principle

The central thesis is that a benchmark's feature footprint F(D) = ∪_{i=1}^N F(xi) encodes the capabilities it probes. By comparing feature footprints across benchmarks, one can:

1. **Detect redundancy**: |F(S)| ≈ |F(D)| for small S implies redundancy
2. **Measure similarity**: |F(D1) ∩ F(D2)| / |F(D1)| measures containment
3. **Identify gaps**: Features present in training data but absent from evaluation benchmarks indicate untested capabilities
4. **Guide synthesis**: Missing features F_miss guide targeted data generation [^551^]

### 5.2 FAC Synthesis: Feature-Guided Data Generation

Claim: Feature Activation Coverage (FAC) quantifies data diversity in a model's internal feature space, and FAC Synthesis achieves comparable performance to MAGPIE using only 2,000 synthetic samples versus MAGPIE's ~300,000 samples (150x reduction) [^551^].
Source: Synthesizing Diverse Data in Feature Space of LLMs
URL: https://arxiv.org/html/2602.10388v2
Date: 2026-02-12
Excerpt: "Experimental results demonstrate that FAC serves as an effective diversity metric, exhibiting a strong positive correlation with downstream task performance (Pearson r=0.95, Spearman ρ=0.90). Our FAC Synthesis method achieves comparable performance to prior SOTA MAGPIE using only 2,000 synthetic samples (MAGPIE requires 150x more data)."
Context: Demonstrates that feature gaps can directly guide targeted training data synthesis with dramatic efficiency gains.
Confidence: high

### 5.3 Theoretical Foundation

The FAC Synthesis paper derives an upper bound on post-training generalization error, identifying **task-relevant feature coverage as a key factor** for superior downstream performance [^551^]. The synthesis process:

1. Train SAE on model's internal feature space
2. Extract task-relevant features from anchor data D and current data D_gen
3. Define missing features: F_miss = features in D but not in D_gen
4. For each missing feature i ∈ F_miss, generate contrastive pairs (x_i^+, x_i^-)
5. Use pairs as few-shot demonstrations to guide generation
6. Filter candidates by SAE activation threshold δ

Claim: Coverage-guided synthesis reduces distribution gap in feature space rather than text space, making it less sensitive to linguistic variation [^551^].
Source: FAC Synthesis paper
URL: https://arxiv.org/html/2602.10388v2
Date: 2026-02-12
Excerpt: "We propose reducing this gap at the SAE feature space, which encodes semantics and functional properties aligned to the target task while being less sensitive to raw input variation."
Context: Feature-space optimization is fundamentally different from and more semantically grounded than text-space diversity metrics.
Confidence: high

---

## 6. Evaluation Efficiency: Reducing Compute Cost While Maintaining Signal

### 6.1 The Cost Problem

Claim: Evaluating a single LLM on HELM costs over 4,000 GPU hours (>$10,000 for APIs), and benchmarks like AlpacaEval require commercial LLM judges, further increasing costs [^594^].
Source: The Anatomy of an LLM Benchmark (Wolfe, 2026)
URL: https://cameronrwolfe.substack.com/p/llm-bench
Date: 2026-03-30
Excerpt: "Evaluating the performance of a single LLM on HELM costs over 4K GPU hours (or over $10K for APIs). Benchmarks like AlpacaEval also require a commercial LLM as a judge to perform evaluation, further increasing the costs."
Context: Evaluation cost is a major bottleneck in LLM development.
Confidence: high

### 6.2 tinyBenchmarks: IRT-Based Subset Selection

Claim: tinyBenchmarks uses Item Response Theory to estimate LLM performance with ~100 curated examples per scenario, achieving within ~2% error on average compared to full benchmark evaluation [^593^].
Source: tinyBenchmarks: evaluating LLMs with fewer examples
URL: https://arxiv.org/html/2402.14992v1
Date: 2024-02-22
Excerpt: "Overall, we conclude that 100 curated examples per scenario are enough to reliably estimate the performance of various LLMs, within about 2% error on average."
Context: IRT-based methods provide a complementary approach to SAE-based redundancy detection.
Confidence: high

### 6.3 SubLIME: Adaptive Subset Selection

Claim: SubLIME reduces evaluation costs by 10-100x through adaptive sampling while preserving ranking fidelity (Spearman ρ > 0.9), using a Rank Correlation Prediction model trained on as few as 5 anchor LLMs [^555^].
Source: SubLIME*: Data Efficient Foundation Model Evaluation
URL: https://openreview.net/pdf/81da27b7afc2e09766f9f405173cce0cf1ec6b12.pdf
Date: Under review (ICLR)
Excerpt: "We introduce SubLIME* (Less Is More for Evaluation), an extensible framework that reduces evaluation costs by 10-100x through adaptive sampling while preserving ranking fidelity (Spearman ρ > 0.9)."
Context: Combines multiple sampling strategies (difficulty, quality, diversity) for optimal subset selection.
Confidence: medium

### 6.4 SAE-Based vs. IRT-Based Efficiency Comparison

| Method | Approach | Data Required | Key Metric |
|--------|----------|--------------|------------|
| SAE Feature Redundancy | Feature coverage curves | SAE activations on benchmark | Spearman ρ ≈ 0.85 vs. ground truth |
| tinyBenchmarks (IRT) | Item Response Theory | Historical evaluation results | ~2% error with 100 examples |
| SubLIME | Rank Correlation Prediction | 5-20 anchor LLMs | Spearman ρ > 0.9 at 10-100x reduction |
| ACE (Active Learning) | Gaussian Process in latent space | Frontier model for capability decomposition | 0.01 RMSE with <50% capabilities evaluated |

### 6.5 Resa: Extreme Training Cost Reduction via SAEs

Claim: Resa uses sparse autoencoder tuning (SAE-Tuning) to retain 97% of RL-trained counterpart's performance while reducing training costs by 2000x to roughly $1 and training time by 450x to around 20 minutes [^559^].
Source: Resa: Efficient Reasoning Models via SAEs
URL: https://openreview.net/forum?id=vUrZaERt8b
Date: 2025-10-08
Excerpt: "When applied to certain Qwen-style models before further RL training, SAE-Tuning retains 97% of its RL-trained counterpart's performance while reducing training costs by 2000x to roughly $1 and training time by 450x to around 20 minutes."
Context: SAEs can dramatically reduce not just evaluation cost but also training cost for capability transfer.
Confidence: high

---

## 7. Meta-Evaluation: What Makes a Good Benchmark?

### 7.1 A Meta-Evaluation Framework for QA Benchmarks

Claim: A comprehensive meta-evaluation framework identifies 8 criteria with 44 sub-criteria: memorization robustness, prompt robustness, evaluation design, evaluator design, reproducibility, comparability, validity (face, substantive, discriminant, convergent), and reliability (test-retest, internal consistency, inter-rater) [^509^].
Source: A Meta-Evaluation Framework for Question & Answer LLM Benchmarks
URL: https://arxiv.org/html/2504.14039v1
Date: 2025-04-18
Excerpt: "We outline our meta-evaluation criteria in Table 1... focusing on the 44 sub-criteria and our scoring rubric for each one... Validity sub-criteria include face validity, substantive validity, discriminant validity and convergent validity... Reliability includes test-retest reliability, internal consistency, and inter-rater reliability."
Context: Provides a structured framework for assessing benchmark quality independent of SAE methods.
Confidence: high

### 7.2 Benchmark Agreement and Tier Effects

Claim: Benchmark agreement is not uniform across model tiers—bottom-tier models exhibit higher agreement (Kendall τ ≈ 0.5), while middle-tier models show low agreement (τ < 0.2) and top-tier models demonstrate low-to-medium agreement (τ ≈ 0.3) [^519^].
Source: Benchmark Meta 2 Evaluation - How to get it right
URL: https://arxiv.org/html/2407.13696v1
Date: 2024-07-18
Excerpt: "Bottom-tier models exhibit higher agreement among themselves, with Kendall correlation coefficients just below 0.5. In contrast, middle-tier models show low agreement (coefficients below 0.2), and top-tier models demonstrate low to medium agreement (around 0.3)."
Context: Benchmark validity varies by model capability level, complicating meta-evaluation.
Confidence: high

### 7.3 Fluid Benchmarking: IRT-Based Dynamic Item Selection

Claim: Fluid Benchmarking adapts IRT to language models, learning item characteristics (difficulty, discrimination) from publicly available evaluation results, achieving higher validity and lower variance than standard methods while using 50x fewer items [^576^].
Source: Fluid language model benchmarking (Ai2)
URL: https://allenai.org/blog/fluid-benchmarking
Date: 2025-09-16
Excerpt: "On MMLU, it achieves higher validity and lower variance than standard methods while using fifty times fewer items, thus simultaneously reducing evaluation costs and improving evaluation quality."
Context: Dynamic benchmarking adapts to each model's capability level, potentially more efficient than static subset selection.
Confidence: high

---

## 8. Dataset Cartography and Training Dynamics

### 8.1 Swayamdipta's Data Maps

Claim: Data Maps leverage training dynamics (model confidence and variability across epochs) to characterize datasets into three regions: ambiguous (contributes to OOD generalization), easy-to-learn (important for optimization), and hard-to-learn (often labeling errors) [^577^].
Source: Dataset Cartography: Mapping and Diagnosing Datasets with Training Dynamics
URL: https://aclanthology.org/2020.emnlp-main.746.pdf
Date: 2020 (EMNLP)
Excerpt: "We leverage a largely ignored source of information: the behavior of the model on individual instances during training (training dynamics) for building data maps. This yields two intuitive measures for each example—the model's confidence in the true class, and the variability of this confidence across epochs—obtained in a single run of training."
Context: Training dynamics provide complementary information to SAE features for dataset quality assessment.
Confidence: high

### 8.2 When Dataset Cartography Fails

Claim: Dataset cartography using training dynamics does not necessarily improve robustness against adversarial datasets, as the method relies on model-dependent measures that may not capture adversarially-induced distribution shifts [^512^].
Source: When is dataset cartography ineffective?
URL: https://arxiv.org/html/2503.18290v1
Date: 2025-03-24
Excerpt: "I leverage dataset cartography to categorize training examples into easy-to-learn, ambiguous, and hard-to-learn subsets based on their training dynamics... I interpret these findings in my discussion."
Context: Dataset cartography has limitations for adversarial robustness evaluation.
Confidence: medium

---

## 9. Active Learning for Evaluation

### 9.1 ACE: Active Learning for Capability Evaluation

Claim: ACE (Active learning for Capability Evaluation) formulates capability evaluation as approximating a latent capability function f_Ω: C → R_+, using Gaussian Processes with active learning to achieve within 0.01 RMSE of exhaustive evaluation by evaluating less than half of capabilities [^512^].
Source: Automated Capability Evaluation of Foundation Models
URL: https://arxiv.org/html/2505.17228v2
Date: 2025-10-09
Excerpt: "It reaches within 0.01 RMSE of exhaustive evaluation by evaluating less than half of capabilities... In Mathematics, ACE generated 433 capabilities and 11,800 tasks, covering 94% of Wikipedia-defined skills in the domain while introducing novel, coherent ones."
Context: Active learning provides a principled statistical framework for efficient evaluation, complementary to SAE-based methods.
Confidence: high

### 9.2 QUIRE: Querying Informative and Representative Examples

Claim: QUIRE provides a systematic way to measure and combine informativeness and representativeness for active learning, using prediction uncertainty based on both labeled and unlabeled data [^506^].
Source: Active Learning by Querying Informative and Representative Examples
URL: https://proceedings.neurips.cc/paper/2010/file/5487315b1286f907165907aa8fc96619-Paper.pdf
Date: 2010 (NeurIPS)
Excerpt: "The proposed approach is based on the min-max view of active learning, which provides a systematic way for measuring and combining the informativeness and the representativeness."
Context: Foundational work on active learning that underlies modern evaluation optimization.
Confidence: high

---

## 10. Capability Elicitation and Latent Capability Measurement

### 10.1 The Elicitation Game

Claim: Fine-tuning is the most effective method for eliciting latent capabilities; for code-generation tasks, only fine-tuning can elicit hidden capabilities of circuit-broken models, while prompting techniques work for MCQA settings but steering fails [^502^].
Source: The Elicitation Game: Evaluating Capability Elicitation Techniques
URL: https://arxiv.org/abs/2502.02180
Date: 2025-02-04
Excerpt: "Prompting techniques can elicit the actual capability of both password-locked and circuit-broken model organisms in the MCQA setting, while steering fails to do so. For a code-generation task, only fine-tuning can elicit the hidden capabilities of our novel model organism."
Context: Capability elicitation is critical for accurate evaluation—latent capabilities may not be visible without proper prompting or fine-tuning.
Confidence: high

### 10.2 Quantifying Elicitation

Claim: Training as few as 10-100 randomly chosen parameters can recover up to 50% of the performance gap between pretrained-only and full fine-tuned models, and 1,000s to 10,000s of parameters can recover 95% of the gap, with a logistic curve fitting the relationship [^513^].
Source: Quantifying Elicitation of Latent Capabilities in Language Models
URL: https://openreview.net/forum?id=Dkgx2pS4Ww
Date: 2025-10-29
Excerpt: "We find that training as few as 10-100 randomly chosen parameters—several orders of magnitude fewer than state-of-the-art parameter-efficient methods—can recover up to 50% of the performance gap between pretrained-only and full fine-tuned models, and 1,000s to 10,000s of parameters can recover 95% of this performance gap."
Context: Elicitation may require only minimal parameter changes, suggesting capabilities are often "present but dormant" rather than absent.
Confidence: high

### 10.3 AISI Structured Protocol for Elicitation

Claim: The UK AI Safety Institute has standardized elicitation experiment practices across workstreams to ensure experiments are more reproducible, comparable, and analysable [^503^].
Source: A structured protocol for elicitation experiments
URL: https://www.aisi.gov.uk/blog/our-approach-to-ai-capability-elicitation
Date: 2025-07-16
Excerpt: "Capability elicitation experiments are designed to unlock or enhance a model's latent abilities after it has been trained... Techniques include: Using prompts that encourage strategic thinking or task decomposition; Giving the model access to external tools; Generating multiple candidate responses; Embedding the model within an agent scaffold; Creating multi-agent setups."
Context: Elicitation is recognized as a critical component of safety evaluation by major AI safety institutions.
Confidence: high

---

## 11. Benchmark Fingerprinting and Behavioral Signatures

### 11.1 Behavioral Fingerprints from Normal Interaction

Claim: A supervised learning approach for fingerprinting LLMs based on semantic embeddings of generated text achieves 89% accuracy in identifying source models, with robust generalization across unseen model versions [^516^].
Source: Large Language Model Fingerprints From Normal Interaction
URL: https://boazbk.github.io/mltheoryseminar/student_projects/final_papers_and_posters/papers/CS2881_Final_Project_-_Annesya_Banerjee.pdf
Date: Unknown
Excerpt: "Using responses from seven major LLMs to 4,410 prompts, our classifier achieves 89% accuracy in identifying source models. The method demonstrates robust generalization across unseen model versions, significantly improved performance with test-time scaling, maintains high performance across different sequence lengths, and reveals behavioral fingerprints of distilled models."
Context: Behavioral fingerprinting can identify model provenance, which is relevant for benchmark contamination detection.
Confidence: medium

### 11.2 Comprehensive Fingerprinting Taxonomy

Claim: LLM fingerprinting methodologies can be categorized by access level (white-box vs. black-box) and approach (intrinsic vs. injected), including methods like HuRef (visual fingerprints with ZK proofs), REEF (CKA-based lineage detection), IF (instruction tuning backdoors), Chain&Hash (cryptographic Q-A chains), and ProFLingo (adversarial query probing) [^511^].
Source: A Behavioral Fingerprint for Large Language Models
URL: https://arxiv.org/html/2602.09434v1
Date: 2026-02-10
Excerpt: "The field of large language model (LLM) fingerprinting has seen rapid development... Methodologies can be broadly categorized by the level of access required (white-box vs. black-box) and the approach taken (intrinsic vs. injected)."
Context: Fingerprinting is relevant for detecting benchmark leakage and ensuring evaluation integrity.
Confidence: high

---

## 12. Dynamic Benchmark Generation and Contamination Resistance

### 12.1 Dynamic Benchmarking for Code Models

Claim: Dynamic benchmarking applies semantic-preserving mutations (e.g., constant unfolding, variable renaming) to code benchmarks, causing consistent performance degradation and reintroducing meaningful differentiation among state-of-the-art models on benchmarks that had become saturated [^510^].
Source: Is Your Benchmark (Still) Useful? Dynamic Benchmarking for Code Language Models
URL: https://arxiv.org/html/2503.06643v1
Date: 2025-03-09
Excerpt: "After applying the Constant Unfolding method, the performance of many models dropped by more than 10% compared to their performance on the original benchmark... On the original CodeNet benchmark, the GPT-4o mini model achieves 91.83%, but after Constant Unfolding, Pass@1 drops to 72.49%."
Context: Dynamic mutations address benchmark saturation—a problem that SAE-based redundancy analysis can identify.
Confidence: high

### 12.2 Code2Bench: Property-Based Testing for Rigorous Evaluation

Claim: Code2Bench uses property-based testing (PBT) to expose "near-perfect failures"—submissions that pass most test cases but fail edge cases, with even top models (DeepSeek-V3, Claude-4-sonnet) experiencing ~8% near-perfect failure rates [^515^].
Source: Code2Bench: Scaling Source and Rigor for Dynamic Benchmark Construction
URL: https://arxiv.org/html/2508.07180v2
Date: 2026-02-03
Excerpt: "Top-performing models are not immune to this illusion of correctness; 'DeepSeek-V3' and 'Claude-4-sonnet', for example, see approximately 8% of their submissions fall into this category."
Context: Rigorous testing paradigms expose weaknesses that aggregate metrics miss.
Confidence: high

---

## 13. Cross-Model and Cross-Task Feature Transferability

### 13.1 SAE Features Generalize Across Model Scales

Claim: SAE-derived features achieve macro F1 > 0.8, outperforming hidden-state and bag-of-words baselines, while demonstrating cross-model transfer from Gemma 2 2B to 9B-IT models and zero-shot generalization to cross-lingual toxicity detection [^573^].
Source: Sparse Autoencoder Features for Classifications and Transferability
URL: https://arxiv.org/html/2502.11367v2
Date: 2025-02-17
Excerpt: "SAE-derived features achieve macro F1 > 0.8, outperforming hidden-state and BoW baselines while demonstrating cross-model transfer from Gemma 2 2B to 9B-IT models. These features generalize in a zero-shot manner to cross-lingual toxicity detection and visual classification tasks."
Context: SAE features are not model-specific—they capture transferable representational structures.
Confidence: high

### 13.2 Cross-Lingual Feature Transfer

Claim: Cross-lingual overlaps in top-20 SAE features are often low (0.06-0.26 between English and other languages), yet English Transfer and Translated SAE configurations can still yield competitive F1 scores, suggesting that a significant subset of high-impact features is useful across languages [^547^].
Source: Sparse Autoencoder Features for Classifications and Transferability (EMNLP 2025)
URL: https://aclanthology.org/2025.emnlp-main.1521.pdf
Date: 2025
Excerpt: "Cross-lingual overlaps (e.g., Overlap English for Spanish or Chinese) are comparatively low (often around 0.06-0.26)... Despite relatively small overlaps in top features, the English Transfer and Translated SAE configurations can still yield competitive F1 scores."
Context: Features have partial cross-lingual transfer, but native training remains superior.
Confidence: high

### 13.3 Smaller Models Predicting Larger Models

Claim: 2B-based SAE features can predict 9B-IT's correctness nearly as well as, and sometimes better than, 9B-IT's own features, suggesting a scalable mechanism for model oversight [^573^].
Source: Sparse Autoencoder Features for Classifications and Transferability
URL: https://arxiv.org/html/2502.11367v2
Date: 2025-02-17
Excerpt: "Surprisingly, 2B-based SAE features can predict 9B-IT's correctness nearly as well as, and sometimes better than, 9B-IT's own features. This is a key result for scalable oversight."
Context: SAE features enable cross-model behavioral prediction, relevant for efficient evaluation and oversight.
Confidence: high

---

## 14. Item Response Theory and Psychometric Approaches

### 14.1 MedIRT for Medical Benchmarks

Claim: MedIRT, a psychometric evaluation framework grounded in Item Response Theory, jointly models latent competency and item-level difficulty/discrimination, correctly predicting held-out LLM responses with 83.3% accuracy, and IRT-based rankings outperform accuracy-based rankings across 6 independent benchmarks with 18% lower variance [^572^].
Source: Item-Aware Evaluation Across Medical Benchmarks
URL: https://arxiv.org/html/2509.24186v2
Date: 2026-04-06
Excerpt: "As internal validation, MedIRT correctly predicts held-out LLM responses on unseen questions with 83.3% accuracy. As external validation, IRT-based rankings outperform accuracy-based rankings across 6 independent external medical benchmarks... achieving 4 wins, 0 losses, and 18% lower variance."
Context: IRT provides a principled statistical framework that complements SAE feature analysis.
Confidence: high

### 14.2 IRT Item Characteristics

IRT models yield two key parameters per benchmark item [^576^]:
- **Difficulty**: The capability level at which a model has 50% probability of answering correctly
- **Discrimination**: How sharply the item distinguishes between models of differing capabilities

Items with low discrimination are often problematic (e.g., mislabeled), and items that are too easy can be filtered out to improve evaluation efficiency.

---

## 15. Mechanistic Interpretability Benchmarks and Automated Evaluation

### 15.1 MIB: Mechanistic Interpretability Benchmark

Claim: MIB (Mechanistic Interpretability Benchmark) provides standardized tasks for evaluating featurization and localization methods, including circuit localization and causal variable localization tracks, with publicly available leaderboards [^548^].
Source: MIB: A Mechanistic Interpretability Benchmark
URL: https://arxiv.org/html/2504.13151v2
Date: 2025
Excerpt: "MIB contains two tracks. The circuit localization track benchmarks methods that aim to locate graphs of causal dependencies in neural networks. The causal variable localization track benchmarks methods that aim to locate specific human-interpretable causal variables in neural networks."
Context: Standardized benchmarks for interpretability methods are emerging, addressing a key gap.
Confidence: high

### 15.2 Machine Interpretability Score (MIS)

Claim: MIS automates interpretability evaluation without humans, using feature encoders (DreamSim) to compute image similarities, and proves highly correlated with human interpretability ratings while enabling evaluation of over 70 million units from 835 computer vision models [^546^].
Source: Measuring Mechanistic Interpretability at Scale Without Humans
URL: https://brendel-group.github.io/mis/
Date: Unknown
Excerpt: "We introduce the first scalable method to measure the per-unit interpretability in vision DNNs. This method does not require any human evaluations, yet its prediction correlates well with existing human interpretability measurements... performing this analysis with human evaluations would have amounted in costs of around one billion USD."
Context: Automated interpretability evaluation at scale is feasible and cost-effective.
Confidence: high

---

## 16. SAE Training Dynamics and Feature Quality

### 16.1 Dead Features and Resurrection

Claim: In TopK SAEs, dead latents can be addressed through encoder weight initialization (W_enc = W_dec^T) and auxiliary loss terms (AuxK) that revive inactive features by using them to model reconstruction error [^554^].
Source: Evaluation of Sparse Autoencoder-based Refusal Features
URL: https://repositum.tuwien.at/bitstream/20.500.12708/220332/1/Kerl%20Tilman%20-%202025%20-%20Evaluation%20of%20Sparse%20Autoencoder-based%20Refusal%20Features%20in...
Date: 2025
Excerpt: "Initializing the encoder weights to be the transpose of the decoder weights (W_enc = W_dec^T) has been found to be an important factor in preventing dead latents... an auxiliary loss term can be introduced to revive dead latents."
Context: Feature quality depends on training dynamics; dead features reduce effective coverage.
Confidence: high

### 16.2 Neuron Resonance and Theoretical Recovery Guarantees

Claim: Neurons reliably learn monosemantic features when their activation frequency matches the feature's occurrence frequency in the data. A bias adaptation algorithm provides the first SAE training algorithm with theoretical recovery guarantees [^600^].
Source: Taming Polysemanticity in LLMs: Theory-Grounded Feature Recovery
URL: https://openreview.net/forum?id=VtWkPIbAQ8
Date: 2025-10-08
Excerpt: "We identify a striking phenomenon we term neuron resonance: neurons reliably learn monosemantic features when their activation frequency matches the feature's occurrence frequency in the data... We theoretically prove that this algorithm correctly recovers all monosemantic features when input data is sampled from our proposed statistical model."
Context: Theoretical foundations for SAE feature recovery are emerging, validating the empirical approach.
Confidence: medium

---

## 17. Representation Engineering and Activation Steering

### 17.1 Steering Vector Sparsification

Claim: Steering vectors can be sparsified by up to 90-99% while retaining most performance, and different steering methodologies agree on a subset of important dimensions [^596^].
Source: What Drives Representation Steering? A Mechanistic Case Study on Steering Refusal
URL: https://arxiv.org/html/2604.08524v1
Date: 2026-04-09
Excerpt: "Leveraging the activation patching results, we show that steering vectors can be sparsified by up to 90-99% while retaining most performance, and that different steering methodologies agree on a subset of important dimensions."
Context: Steering vectors have redundant dimensions, suggesting that effective control requires only a small subset of features.
Confidence: high

### 17.2 Multi-Token Activation Patching

Claim: Multi-token activation patching reveals that steering vectors primarily interact with the attention mechanism through the OV circuit while largely ignoring the QK circuit—freezing all attention scores during steering drops performance by only ~8.75% [^596^].
Source: What Drives Representation Steering?
URL: https://arxiv.org/html/2604.08524v1
Date: 2026-04-09
Excerpt: "These circuits reveal that steering vectors primarily interact with the attention mechanism through the OV circuit while largely ignoring the QK circuit—freezing all attention scores during steering drops performance by only ~8.75% across two model families."
Context: Mechanistic understanding of steering helps identify which features actually control behavior.
Confidence: high

---

## 18. Key Questions Answered

### Q1: Can SAE feature overlap predict model performance on a benchmark without running it?

**Answer**: Indirectly, yes. Feature overlap predicts *benchmark redundancy* (Spearman ρ ≈ 0.85 with performance-based redundancy) [^5^] and *capability similarity* (partial Pearson correlation of 75.5% after controlling for general ability) [^5^]. However, it does not directly predict absolute performance scores—it predicts whether benchmarks measure similar capabilities and whether subsets preserve ranking. The correlation is strong enough to guide evaluation suite design without model execution.

### Q2: What is the mathematical formulation of feature coverage and redundancy?

**Answer**:
- **Feature set per sample**: F(xi) = {j : zj(xi) > 0}
- **Feature footprint**: F(D) = ∪_{i=1}^N F(xi)
- **Expected coverage at size n**: cn = E[|F(S)| / |F(D)|]
- **Feature redundancy**: R̂(D) = (Σ_{n=1}^N cn) / |F(D)|
- **Asymmetric overlap**: overlap(D1, D2) = |F(D1) ∩ F(D2)| / |F(D1)|

These formulations are from Qwen-Scope [^5^] and have been validated against ground-truth performance-based redundancy across 17 benchmarks.

### Q3: How much compute does SAE-based benchmark analysis save?

**Answer**:
- SAE-based redundancy analysis requires only **one forward pass per benchmark sample** through the SAE (which is much smaller than the model itself)
- Compared to O(M × N) model evaluations for performance-based redundancy, this is a reduction from M×N full model forward passes to N SAE encodings
- For 26 models on a 1,319-sample benchmark: ~34,294 full evaluations vs. 1,319 SAE encodings → ~26x reduction even before considering that SAEs are smaller
- Complementary approaches achieve further savings: SubLIME reduces costs 10-100x [^555^], tinyBenchmarks achieves ~2% error with 100 examples [^593^], and ACE reaches 0.01 RMSE with <50% evaluation [^512^]
- For training: Resa achieves 2000x cost reduction using SAE-Tuning [^559^]

### Q4: Can feature gaps guide targeted training data synthesis?

**Answer**: Yes. FAC Synthesis [^551^]:
1. Identifies missing features F_miss by comparing anchor data vs. current data
2. Generates contrastive pairs (strong/weak feature activation)
3. Uses pairs as few-shot demonstrations for targeted generation
4. Filters by SAE activation threshold

Results: FAC achieves Pearson r=0.95 with downstream performance, and FAC Synthesis matches MAGPIE performance with 150x fewer samples (2,000 vs. ~300,000).

---

## 19. Synthesis and Integration

### The Evaluation Stack

A complete SAE-based evaluation intelligence pipeline combines multiple layers:

| Layer | Function | Key Method |
|-------|----------|------------|
| **Feature Extraction** | Decompose activations into interpretable features | TopK SAE encoding |
| **Fingerprinting** | Characterize benchmarks by feature footprint | F(D) = ∪ F(xi) |
| **Redundancy Detection** | Identify benchmarks with saturated coverage | R̂(D) = Σ cn / |F(D)| |
| **Similarity Analysis** | Measure capability overlap between benchmarks | Asymmetric overlap |
| **Gap Identification** | Find untested capabilities | F_miss = F(anchor) \ F(current) |
| **Data Synthesis** | Generate samples targeting missing features | FAC Synthesis |
| **Efficient Evaluation** | Select minimal representative subsets | IRT + active learning |
| **Contamination Detection** | Detect training-test overlap | Feature/n-gram overlap |

### Proven vs. Experimental vs. Theoretical

| Status | Findings |
|--------|----------|
| **PROVEN** | SAE feature redundancy correlates with performance redundancy (ρ ≈ 0.85) [^5^]; TopK SAE architecture is effective [^554^]; Feature overlap predicts benchmark similarity (75.5% partial correlation) [^5^]; FAC correlates with downstream performance (r=0.95) [^551^] |
| **EXPERIMENTAL** | FAC Synthesis with 150x sample reduction [^551^]; Cross-model feature transfer [^573^]; Resa 2000x training cost reduction [^559^]; Fluid Benchmarking 50x item reduction [^576^] |
| **THEORETICAL** | Bias adaptation SAE with recovery guarantees [^600^]; Upper bounds on post-training generalization via feature coverage [^551^]; Neuron resonance phenomenon [^600^] |

### Limitations and Open Questions

1. **Layer selection**: Which layer's SAE features best represent benchmark capabilities? Qwen-Scope uses a single layer; multi-layer analysis may improve fidelity.
2. **Feature interpretability**: Not all SAE features are human-interpretable. Auto-interpretation methods remain imperfect.
3. **Cross-architecture transfer**: Most validation is within model families (Qwen, Gemma). Cross-family generalization needs more study.
4. **Causal vs. correlational**: Feature overlap shows correlation with performance similarity; causal direction is not fully established.
5. **Dynamic capabilities**: Models may develop new capabilities during evaluation that weren't present when SAEs were trained.
6. **Sophisticated reasoning**: Multi-layer distributed circuits for complex reasoning are harder to capture with single-layer SAE features [^551^].

---

## References

[^5^] Qwen-Scope: Turning Sparse Features into Development Tools for Large Language Models. Qwen Team, 2026. https://qianwen-res.oss-accelerate.aliyuncs.com/qwen-scope/Qwen_Scope.pdf

[^475^] The Geometry of Concepts: Sparse Autoencoder Feature Structure. PMC, 2025. https://pmc.ncbi.nlm.nih.gov/articles/PMC12025678/

[^473^] Group-SAE: Efficient Training of Sparse Autoencoders. ACL Anthology, 2025. https://aclanthology.org/2025.emnlp-main.942.pdf

[^502^] The Elicitation Game: Evaluating Capability Elicitation Techniques. arXiv, 2025. https://arxiv.org/abs/2502.02180

[^503^] A structured protocol for elicitation experiments. AISI, 2025. https://www.aisi.gov.uk/blog/our-approach-to-ai-capability-elicitation

[^506^] Active Learning by Querying Informative and Representative Examples (QUIRE). NeurIPS, 2010. https://proceedings.neurips.cc/paper/2010/file/5487315b1286f907165907aa8fc96619-Paper.pdf

[^509^] A Meta-Evaluation Framework for Question & Answer LLM Benchmarks. arXiv, 2025. https://arxiv.org/html/2504.14039v1

[^510^] Is Your Benchmark (Still) Useful? Dynamic Benchmarking for Code Language Models. arXiv, 2025. https://arxiv.org/html/2503.06643v1

[^512^] Automated Capability Evaluation of Foundation Models (ACE). arXiv, 2025. https://arxiv.org/html/2505.17228v2

[^513^] Quantifying Elicitation of Latent Capabilities in Language Models. OpenReview, 2025. https://openreview.net/forum?id=Dkgx2pS4Ww

[^515^] Code2Bench: Scaling Source and Rigor for Dynamic Benchmark Construction. arXiv, 2026. https://arxiv.org/html/2508.07180v2

[^516^] Large Language Model Fingerprints From Normal Interaction. Student paper, undated. https://boazbk.github.io/mltheoryseminar/student_projects/final_papers_and_posters/papers/CS2881_Final_Project_-_Annesya_Banerjee.pdf

[^519^] Benchmark Meta 2 Evaluation - How to get it right. arXiv, 2024. https://arxiv.org/html/2407.13696v1

[^546^] Measuring Mechanistic Interpretability at Scale Without Humans (MIS). https://brendel-group.github.io/mis/

[^547^] Sparse Autoencoder Features for Classifications and Transferability. arXiv, 2025. https://arxiv.org/html/2502.11367v2

[^548^] MIB: A Mechanistic Interpretability Benchmark. arXiv, 2025. https://arxiv.org/html/2504.13151v2

[^551^] Synthesizing Diverse Data in Feature Space of LLMs (FAC Synthesis). arXiv, 2026. https://arxiv.org/html/2602.10388v2

[^553^] Building Sparse Autoencoders (SAEs) from Scratch. Medium, 2026. https://medium.com/data-science-collective/building-sparse-autoencoders-saes-from-scratch-b93c1a72e0ac

[^554^] Evaluation of Sparse Autoencoder-based Refusal Features. TU Wien, 2025. https://repositum.tuwien.at/bitstream/20.500.12708/220332/1/Kerl%20Tilman%20-%202025%20-%20Evaluation%20of%20Sparse%20Autoencoder-based%20Refusal%20Features%20in...

[^555^] SubLIME*: Data Efficient Foundation Model Evaluation. OpenReview, undated. https://openreview.net/pdf/81da27b7afc2e09766f9f405173cce0cf1ec6b12.pdf

[^556^] Route Sparse Autoencoder to Interpret Large Language Models. ACL Anthology, 2025. https://aclanthology.org/2025.emnlp-main.346.pdf

[^559^] Resa: Efficient Reasoning Models via SAEs. OpenReview, 2025. https://openreview.net/forum?id=vUrZaERt8b

[^572^] Item-Aware Evaluation Across Medical Benchmarks (MedIRT). arXiv, 2026. https://arxiv.org/html/2509.24186v2

[^573^] Sparse Autoencoder Features for Classifications and Transferability (MOSAIC). EMNLP 2025. https://aclanthology.org/2025.emnlp-main.1521.pdf

[^576^] Fluid language model benchmarking. Ai2 Blog, 2025. https://allenai.org/blog/fluid-benchmarking

[^577^] Dataset Cartography: Mapping and Diagnosing Datasets with Training Dynamics. EMNLP 2020. https://aclanthology.org/2020.emnlp-main.746.pdf

[^593^] tinyBenchmarks: evaluating LLMs with fewer examples. arXiv, 2024. https://arxiv.org/html/2402.14992v1

[^594^] The Anatomy of an LLM Benchmark. Wolfe, 2026. https://cameronrwolfe.substack.com/p/llm-bench

[^596^] What Drives Representation Steering? A Mechanistic Case Study on Steering Refusal. arXiv, 2026. https://arxiv.org/html/2604.08524v1

[^600^] Taming Polysemanticity in LLMs: Theory-Grounded Feature Recovery. OpenReview, 2025. https://openreview.net/forum?id=VtWkPIbAQ8
