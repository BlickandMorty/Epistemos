# DemoPSD: Disagreement-Modulated Policy Self-Distillation

arXiv: [2607.02502](http://arxiv.org/abs/2607.02502v1)

Authors: Yunhe Li; Hao Shi; Wenhao Liu; Mengzhe Ruan; Hanxu Hou; Zhongxiang Dai; Shuang Qiu; Linqi Song

Published: 2026-07-02T17:58:29Z

Categories: cs.LG, cs.AI

PDF: https://arxiv.org/pdf/2607.02502v1

## Abstract

On-policy self-distillation (OPSD) has emerged as a practical method for training large language models (LLMs) to reason, where a single model acts as both the teacher and the student with different levels of information access. However, recent studies have found that the teacher's dense token-level supervision, conditioned on privileged information, can lead to overfitting to in-domain patterns, suppress exploration, and hurt cross-domain generalization, while also introducing a more fundamental issue: *privileged information leakage*, where the student encodes answer-dependent shortcuts that are unavailable at test time. We introduce **DemoPSD**, a novel framework that resolves such problems through the idea of *selective adoption of teacher guidance*. Instead of fitting the full teacher distribution, DemoPSD steers the student toward a *reverse-KL barycenter target*, a weighted geometric combination of the teacher and student distributions, that naturally balances learning from the teacher with preserving the student's own reasoning capacity. We measure the difference between their distributions and use such a discrepancy to adaptively control the blending at each token position. We provably show that DemoPSD achieves **(1)** *leakage attenuation*, i.e., effective mitigation of privileged information leakage; and **(2)** *exploration preservation*, i.e., preservation of exploration capacity under dense token-level distillation. Extensive experiments on SciKnowEval across four scientific fields show that DemoPSD outperforms both GRPO and SDPO while maintaining higher training entropy and robustly generalizing to out-of-distribution GPQA benchmarks.

## Parsed Full Text

DemoPSD: Disagreement-Modulated Policy Self-Distillation

arXiv:2607.02502v1 [cs.LG] 2 Jul 2026

|  | DemoPSD: | Disagreement-Modulated |  | Policy |
| --- | --- | --- | --- | --- |
| Yunhe Li *,1 , | Hao Shi *,2 , | Wenhao Liu 2 , | Mengzhe Ruan 1 , | Hanxu Hou 3 |
|  | Zhongxiang Dai 4 , | Shuang Qiu †,1 , | Shuang Qiu †,1 , Linqi Song †,1 |  |

1City University of Hong Kong 2Tsinghua University 3 4 Shenzhen University of Advanced Technology

Chinese University of Hong Kong, Shenzhen uuen.li@my.cityu.edu.hk shih22@mails.tsinghua.edu.cn {shuanqiu,linqi.song}@cityu.edu.hk

Abstract

On-policy self-distillation (OPSD) has emerged as a practical method for training large language models (LLMs) to reason, where a single model acts as both the teacher and the student with different levels of information access. However, recent studies have found that the teacher’s dense token-level supervision, conditioned on privileged information, can lead to overfitting to in-domain patterns, suppress exploration, and hurt cross-domain generalization, while also introducing a more fundamental issue: privileged information leakage, where the student encodes answer-dependent shortcuts that are unavailable at test time. We introduce

# DemoPSD

, a novel framework that resolves such problems through the idea of selective adoption of teacher guidance: the student adopts the teacher’s guidance when their distributions remain reasonably consistent, and relies more on its own reasoning when their distributions substantially diverge, indicating that the teacher’s output is overly influenced by privileged information. Instead of fitting the full teacher distribution, DemoPSD steers the student toward a combination of the teacher and student distributions, that naturally balances learning from the teacher with preserving the student’s own reasoning capacity. We measure the difference between their distributions and use such a discrepancy to adaptively control the blending at each token position. We provably show that DemoPSD achieves (1) leakage attenuation, i.e., effective mitigation of privileged information leakage; and reverse-KL barycenter target

, a weighted geometric

(2) exploration preservation, i.e., preservation of exploration capacity under dense token-level distillation.

Extensive experiments on SciKnowEval across four scientific fields show that DemoPSD outperforms both GRPO and SDPO while maintaining higher training entropy and robustly generalizing to out-of-distribution

GPQA benchmarks.

# 1. Introduction

Reinforcement learning with verifiable rewards (RLVR) has become a central paradigm for post-training large language models on reasoning tasks (Shao et al., 2024, DeepSeek-AI, 2025, Yu et al., 2026a). Methods such as Group Relative Policy Optimization (GRPO) train models by sampling multiple rollouts per question and using

*Equal contribution. †

Corresponding author.

tains 33-98% higher entropy than SDPO across all domains, avoiding policy entropy collapse. domain over training steps.

- Figure 1: DemoPSD preserves higher entropy (left), which translates into better best@16 performance (right).

outcome correctness as a reward signal. While effective, RLVR suffers from a fundamental credit assignment bottleneck: standard RLVR methods distribute a rollout-level reward uniformly among all tokens in a rollout, offering coarse token-level credit signals that fail to distinguish individual token contributions (Hübotter et al., 2026).

On-policy distillation (OPD) addresses this bottleneck by introducing dense, token-level supervision from a teacher model on the student’s self-generated trajectories (Agarwal et al., 2024, Gu et al., 2024, Lu and Thinking Machines Lab, 2025). Unlike off-policy distillation, which trains on teacher-generated texts and suffers from compounding exposure bias (Ross et al., 2011), OPD allows the student to learn from its own distribution while receiving rich feedback. This paradigm has been widely adopted in industry, including Qwen3 (Qwen Team, 2025) and DeepSeek-V4 (DeepSeek-AI, 2026), establishing OPD as a practical complement to RLVR.

A particularly appealing variant is on-policy self-distillation (OPSD) (e.g., Zhao et al., 2026, Hübotter et al., 2026), where a single model serves as both teacher and student. The teacher is the same model conditioned on privileged information, such as a verified reasoning trace or ground-truth answer, while the student receives only the question. OPSD eliminates the need for an external teacher and has demonstrated severalfold improvements in token efficiency over GRPO (Zhao et al., 2026, Shenfeld et al., 2026). However, recent theoretical and empirical analysis has revealed a critical failure mode: privileged information leakage (Yang et al., 2026). Because the teacher conditions on privileged information test time, the OPSD objective contains an irreducible mutual information gap I yt; y x, y<t is a conditional mutual information with x the input question, y<t the generated prefix, yt the next token, ∗ y∗ and y the privileged information available only to the teacher. A positive value indicates that, even after conditioning on the question and generated prefix, the privileged signal still provides additional information about the next token, drving the student to encode answer-dependent shortcuts. This manifests as early performance gains followed by gradual degradation. As a result, the student may internalize cues tied to the privileged information instead of acquiring transferable reasoning strategies (Yang et al., 2026). that the student never observes at ) > 0, which

( ∗ |

This failure mode reflects a broader tension between benefiting from the teacher’s guidance and pre-

2026) uses consensus among multiple teachers. The aforementioned methods share a common intuition: not all tokens are equally trustworthy. Yet they all rely on indirect proxies such as the teacher’s entropy, sample correctness, student entropy, or multi-teacher consensus rather than directly measuring how much the teacher’s prediction is influenced by privileged information. How to design the distillation target itself to balance teacher-guided learning with the student’s own reasoning, however, has received relatively little attention. πtarget(v|x,y ,yˆ )

<t ∝

(︀π

Our work introduces DemoPSD, a novel framework that addresses this challenge in standard OPSD through the principle of selective adoption of teacher guidance: the student adopts the teacher’s guidance when their distributions are reasonably consistent, and relies more on its own reasoning when the teacher’s distribution substantially diverges from the student’s, indicating that the teacher’s output is overly influenced by privileged information. Rather than fitting the full teacher distribution, DemoPSD trains the student toward a reverse-KL barycenter target, which is a weighted geometric combination of the teacher’s and student’s distribution: αt 1−αt ∗ ∗ student teacher <t <t t

(v|x,y ,yˆ ))︀

· (︀π

(v|x,yˆ ))︀ ,

(1) where αt is a per-token leakage attenuation coefficient determined by the disagreement between the distributions of the teacher and the student, controlling how far the target is interpolated from the teacher’s ∗ distribution toward the student’s distribution. When αt is sufficiently small, the privileged information y does not substantially shift the teacher’s distribution, the target therefore remains close to the teacher. As αt in∗ creases, the teacher’s distribution becomes more strongly shaped by y . Forcing the student to directly match the teacher would encode answer-dependent shortcuts into the student, which is precisely the privileged information leakage. The target in (1) is therefore interpolated further toward the student’s distribution to attenuate leakage while preserving the student’s unprivileged reasoning capacity. Figure 1 previews our main empirical results based on the principle of selective adoption of teacher guidance. DemoPSD preserves substantially higher training entropy than SDPO across all domains, which further translates into improved best@16 results. Our contribution. Specifically, our main contributions are three-fold:

1. We propose a novel on-policy self-distillation algorithm DemoPSD that effectively prevents the student model from overfitting the teacher’s distribution, thereby improving both in-domain and cross-domain reasoning capabilities and reducing privileged information leakage during self-distillation. (1) leakage attenuation
2. We theoretically prove two key properties of DemoPSD: weighted reverse-KL barycenter target reduces the rate of privileged information leakage; and (2) ex-

, i.e., the disagreement-

# 2. Related Work

On-Policy Distillation and Self-Distillation. Recent OPD methods such as GKD (Agarwal et al., 2024) and MiniLLM (Gu et al., 2024) train the student on model-generated trajectories while using teacher distributions as dense supervision. This on-policy design is motivated by the classic imitation-learning observation that training only on expert-generated states can suffer from compounding errors under distribution shift (Ross et al., 2011). Subsequent work further studies OPD from different perspectives: REOPOLD (Ko et al., 2026) relaxes on-policy distillation for more efficient reasoning, Veto (Jang et al., 2026) reformulates the distillation target to improve training stability, and Song and Zheng (2026) provide a broader survey of OPD methods for large language models. Another line of research focuses on the on-policy self-distillation problem. SelfDistilled Reasoner (Zhao et al., 2026) studies the setting where a single model provides its own on-policy distillation signal for reasoning. SDPO (Hübotter et al., 2026) further frames reinforcement learning through self-distillation, converting sparse outcome feedback into dense training signals. Related variants explore complementary design choices: SD-Zero (He et al., 2026) uses self-revision to transform binary rewards into dense supervision, UniSD (Jin et al., 2026) proposes a unified framework for self-distillation in LLMs, and CRISP (Sang et al., 2026) applies iterative self-policy distillation to compressed reasoning. As shown in §4.3, DemoPSD instead uses a disagreement-dependent geometric target that preserves dense supervision on low-disagreement tokens while attenuating teacher-induced signals on high-disagreement tokens.

Addressing Privileged Information Leakage Recent work has begun to analyze and mitigate failure modes in on-policy self-distillation. Yang et al. (2026) study self-distilled RLVR and identify privileged information leakage as a key concern. HDPO (Ding, 2026) focuses privileged self-distillation on cliff prompts, while PBSD (Yu et al., 2026b) moves beyond direct KL matching through preference-based self-distillation and reward regularization. Other methods adjust when or how self-distillation is applied. SRPO (Li et al., 2026) unifies group-relative optimization and self-distillation through sample routing, DASD (Zhang et al., 2026) adapts supervision according to the direction of the self-distillation signal, and PAINT (Tan and Hong, 2026) interpolates between partial- and full-solution prompts. Kim et al. (2026) analyzes why self-distillation can degrade reasoning ability. In contrast, DemoPSD keeps the token-level distillation setting but changes the distributional target itself: the reverse-KL barycenter adaptively interpolates between the privileged teacher and the unprivileged student according to teacher-student disagreement.

Mixture Distributions and Entropy Dynamics AMiD (Shin et al., 2026) introduces α-mixture assistant distributions for knowledge distillation, making it conceptually related to our reverse-KL barycenter target, although AMiD does not address privileged self-distillation. Entropy stability has also emerged as an important issue in large-scale RL training systems such as DAPO (Yu et al., 2026a) and in explicit entropy-control methods such as EntroPIC (Yang et al., 2025), motivating our focus on preserving exploration during dense distillation. PACED (Xu et al., 2026) studies distillation and on-policy self-distillation at the frontier of student competence, which is complementary to our token-level disagreement-based target adaptation.

# 3. Background and Problem Setting

# 3.1. Reinforcement Learning with Verifiable Rewards

reward

We consider the standard RLVR setup for post-training LLMs. Given a dataset of questions D { ∗ i ∗ where a is the verifiable answer, the model πθ(· | x) generates rollouts y ∼ πθ(· | x) and receives a binary based on outcome correctness. GRPO (Shao et al., 2024) estimates advantages from r(y,a ) ∈ {0,1}

∗ }N

= (xi, ai ) i=1 these rewards within each rollout group and optimizes:

L

GRPO θ

( ) = −

Ex∼D Ey∼πθ (·|x)

[︀Aˆ(y) · log πθ

(y|x)]︀ + βKL

·KL( ∥ ), πθ πref

(2)

ˆ

Aˆ(y)= r(y,a )−µr

,

σr + ϵ where A(y) is the group-relative advantage. For a group of G rollouts {yj}j=1 x, GRPO computes G G ∗ j j k=1 µr

=

1 ⎸ 1 ∑︁ r(y a∗)

G k,

, σr

G sampled for the same question

⎯ ⎷

G

=⎸ ∑︁(︀r(y a∗)− )︀2 k=1 k,

, µr

(3) with a small constant ϵ > 0 for numerical stability. The KL regularizer is defined as

⎡

∥

KL(πθ πref ) = Ex∼D ⎣

∑︁ y

| πθ(y x) log πθ ref

(y|x)

π (y|x)

⎤

⎡ |y| ∑︁ t=1

⎦ = Ex∼D, y∼πθ ⎣ log πθ ref

(y |x,y ) t <t

π (yt | x, y<t)

⎤ ⎦.

(4)

One of the fundamental limitations is that r provides only an outcome reward per response, offering no guidance on which tokens contributed more to success or failure.

# 3.2. On-Policy Self-Distillation

teacher πθ( Given a student-generated rollout yˆ∼π(·|x)

Reinforcement learning via self-distillation (SDPO) (Hübotter et al., 2026) addresses the credit assignment bottleneck by introducing dense, token-level supervision from a privileged version of the same model. The ∗ ∗ θ

· | x, y ) is the current model conditioned on both the question x and privileged information y (e.g., a verified reasoning trace or ground truth), while the student πθ(· | x) receives only the question.

, the SDPO objective minimizes per-token divergence:

L

SDPO θ

( ) =

⎡ |yˆ|

Ex∼D Eyˆ∼πθ (·|x) ⎣

∑︁KL(︀ (·|x,yˆ )∥ <t t=1 πθ

( (·|x,y∗,yˆ )))︀ . <t stopgrad πθ

⎤ ⎦

(5)

The key insight is that the teacher leverages its access to the privileged outcome reward. The stopgrad operator prevents gradients from flowing into the teacher, which keeps the ∗ teacher from shifting toward the student and ignoring y . y∗ to provide richer feedback than an

# 3.3. The Privileged Information Leakage Problem

While SDPO achieves impressive token efficiency, Yang et al. (2026) proved that the setting is fundamentally ill-posed. Since the teacher conditions on privileged information SDPO objective contains an irreducible mutual information gap: ∗

I(yt; y | x, y<t) > 0. y∗ that the student cannot observe, the

(6)

This gap implies the student can never perfectly achieve the teacher’s conditional distribution, regardless ∗ of capacity. At the gradient level, per-sample gradients include an y -specific deviation whose variance is proportional to this mutual information. At the early stage of training, the beneficial gradient component dominates, producing rapid training reward improvement. However, as the student approaches the teacher’s ∗ marginal distribution, the deviation takes over, driving the student to encode x → y correlations, which is exactly the privileged information leakage explained in Yang et al. (2026). Empirically, SDPO performance peaks early and then gradually degrades during the remaining training stage.

The leakage problem points to a deeper issue: the teacher’s distribution is not always an appropriate target for direct fitting. Even if leakage could be eliminated, a student who exactly replicates the teacher has lost its own capacity for reasoning. What we need instead is a training target that adaptively incorporates the teacher’s guidance while preserving the student’s own reasoning ability.

# 4. The Proposed Method: DemoPSD

This section presents the proposed method DemoPSD, built on the principle of selective adoption of teacher guidance, i.e., the student follows the teacher’s guidance when privileged information does not heavily distort the teacher’s distribution so that it diverges substantially from the student’s distribution. Below, we first describe how to measure teacher-student disagreement (§4.1), then introduce the reverse-KL barycenter target that implements selective adoption (§4.2), derive its loss and gradient (§4.3), and describe the full training procedure (§4.4).

# 4.1. Measuring Teacher-Student Disagreement

The key ingredient of DemoPSD is measuring the disagreement between the teacher’s and student’s predictions at each token position: one made with privileged information, and one made without. Token positions where these predictions remain reasonably consistent are likely to reflect transferrable knowledge that the student can safely adopt, while positions where they substantially disagree indicate that the teacher’s output has been overly influenced by privileged information.

# Disagreement and Leakage Attenuation Coefficient.


At each token position , the privileged teacher’s ∗ ∗ t T prediction is obtained by conditioning the model on the question x, the privileged information y , and the student’s rollout prefix yˆ<t. For notational convenience, we write this distribution as π (v, y ) as shorthand π (v|x,y∗,yˆ ) x yˆ

<t . The corresponding student’s prediction conditions only on and <t, and we write it <t . We use these shorthand notations when no ambiguity arises and revert to the full conditional form when the conditioning context needs to be made explicit. The privileged ∗ for θ t (v)

(v|x,yˆ ) as πS asshorthandforπθ prediction provides a rich teacher signal because it receives y , while the student’s prediction serves as the reference distribution for evaluating disagreement. We describe how context in §4.4. In practice, for training stability, we use a separate exponential moving average (EMA) copy of the student when computing the disagreement in (7) and the target distribution in (9); implementation details are summarized in Algorithm 1. We measure the disagreement dt between πT and πS by using the Jensen-Shannon divergence (JSD): t t t t t t y∗ is incorporated into the model’s

1 1 1 2 2 2 dt = JSD(πS ∥πT ) = KL(πS ∥mt ) + KL(πT ∥mt ), mt = (πS + πT ).

(7)

From t, we derive a leakage attenuation coefficient t away from the privileged teacher and toward the student’s own prediction. We require f to be monotonically increasing so that larger teacher-student disagreement leads to stronger leakage attenuation, and to satisfy d α =f(d) t that controls how much the target shifts

use a saturating form with limd→ sigmoid: β α αt= σ(β·dt)−0.5 ·2·αmax,

(︀

)︀ f

(8) β α where controls the sensitivity of the gate to teacher-student disagreement: a larger makes t increase more sharply with small changes in dt, causing the target to move away from the privileged teacher more aggressively, whereas a smaller β yields a smoother transition and retains more teacher signal under moderate disagreement. This realization has two key properties: (1) When αt is sufficiently small, i.e., the two distributions are reasonably consistent, it is safe to distill; (2) As αt increases to αmax, i.e., they strongly disagree, distillation becomes increasingly risky.

# 4.2. Reverse-KL Barycenter Target

Given the coefficient αt, we define the distillation target as a geometric mixture of the two distributions. The target at token position t is: α 1−α αt πtarget

(v|x,y∗,yˆ ) (︀ t(v,y∗))︀

<t∝πT t·(︀ t(v))︀ t. πS

(9) π

This distribution is the reverse-KL barycenter of the privileged teacher and the student distributions under the weight αt, defined by αt target q∈∆(V )

{︀

(︀ ⃦ t )︀

(︀ ⃦ t )︀}︀

= arg min (1 − αt)KL q⃦πT + αtKL q⃦πS

,

(10) where ∆

(V)

V denotes the probability simplex over the vocabulary . The reverse-KL barycenter in (10) defines t t the weighted centroid of a collection of probability distributions, i.e., πT and πS in this problem, under the reverse KL divergence. Equivalently, this target interpolates between the teacher and student distributions in log-probability space, πtarget αt log αt (v|x,y∗,yˆ )=(1− )log t(v,y∗)+ log t(v)−logZ , <t αt πT αt πS

Z where αt is the normalization term for (9) defined as:

Zα = t

∑︁ αt target v π

(v | x, y , yˆ<t).

∗

(11)

((1− )t+ t ) αt πT αtπS for two reasons:

Geometric Mixture vs Arithmetic Mixture. The geometric mixture is chosen over the arithmetic alternative Because probabilities are multiplied, a token receives substantial target mass only when it is supported by both the privileged teacher and the student. Thus, tokens endorsed primarily by the teacher but assigned very low probabilities by the student are naturally suppressed, whereas an arithmetic mixture would still allocate them non-trivial mass. (2) When the teacher and student distributions have different modes, an arithmetic mixture can average the modes into a diffuse target with inflated entropy. The geometric mixture avoids this mode-averaging effect, yielding a sharper and more coherent training signal. This is consistent with AMiD’s (Shin et al., 2026) observation that mixture geometry controls mode-covering versus mode-seeking behavior.

(1)

The student is trained to minimize the reverse KL divergence objective toward the reverse-KL barycenter target:

⎡ |yˆ| ∑︁ t=1

LDemoPSD (θ ) = Ex∼D Eyˆ∼π (·|x) ⎣ θ

(︀ αt

⎤

∗

)︀

KL πθ(· | x, yˆ<t) ∥ stopgrad(πtarget(· | x, y , yˆ<t)) ⎦ .

(12) of L

∇ L

Directly computing and differentiating through the normalization term Zαt would make the optimization t T t complicated. However, the full target distribution is wrapped with stop-gradient: the teacher π , the reference student πS, the weight αt are all treated as fixed during the backward pass. Consequently, αt becomes constant and the optimization hence avoids directly backpropagating through it. Then the gradient DemoPSD | |yˆ θ DemoPSD θ t <t πθ πθ t t θ t=1 takes the following form:

∑︁[︁

Eyˆ ∼ (·|x,yˆ )(1 − αt) log

= Eyˆ∼ (·|x) πθ (yˆt | x, yˆ<t )

π (yˆ |x,y∗,yˆ< ) θ

]︁

∇ logπ (yˆt |x,yˆ<t) .

Z

(13)

The DemoPSD gradient keeps the same reverse-KL score-function form while scaling the teacher-induced log-ratio signal by the disagreement-based factor (1 − αt). As illustrated in (13), positions with larger teacher-student disagreement contribute a weaker distillation signal, reducing the tendency to backpropagate privileged information dependent guidance from the teacher.

4.4. Privileged Information Injection and Training Procedure

Algorithm 1 summarizes the full DemoPSD algorithm.

# Privileged Information Injection.

context: y∗ x

Generally, for each training prompt with privileged information , ∗ and a relevant student-generated rollout yˆ, we construct the teacher’s input by prepending y to the prompt ∗

[Question: x | Privileged Information: y | Student Response: yˆ<t].

The student model receives only:

[Question: x |

Student Response: <t , yˆ ] both of which share the same model. The only difference is whether the privileged information y is included in the conditioning context. Reprompting Mechanism. For a correct rollout, the generated response itself contains rich solution information and can therefore serve as privileged information for the teacher model. Following Hübotter et al. (2026), we use a reprompting mechanism to construct this privileged context: for each prompt group, if at least one rollout is correct, we randomly select one correct rollout as context above; if no rollout is correct, no reliable privileged teacher context can be formed, so the prompt is skipped for distillation. As explained in Hübotter et al. (2026), model performance is not sensitive to syntactic variations of the reprompting template, so we use a similar template to instantiate the privileged information for the teacher model. y∗

∗ and insert it into the teacher

D

| 2: | Sampl e batch { x i } fro m D ; gen erate roll o uts y ˆ i ∼ π θ ( · | x i ) |
| --- | --- | --- |
| 3: | 3: Filter: keep o nly pro mpts with at l ea st o n e correct roll o ut ( r ( y ˆ i , a i ∗ ) = 1 ) |  |
| 4: | for each filtered pro mpt ( x , y ∗ , y ˆ ) do |  |
| 5: | t ∗ |  |
| 6: | Obt ain the student poli cy: π S ← π θ ( · | x , y ˆ < t ) f or a ll t |
| 7: | Co mpute the distrib uti o n a l disa greement d t via ( 7 ) |  |
| 8: | Co mpute the l ea ka ge atten uati o n coeffi ci ent α t via ( 8 ) |  |
| 9: | Co mpute the rev erse-KL barycenter t arget via ( 9 ) |  |
| 10: | end for |  |
| 11: | Update θ via gradi ent descent o n L Dem oPSD ( θ ) |  |

12: end for

# 5. Theoretical Analysis

This work aims to solve a central question that how we preserve the token-level distributional supervision ∗ while suppressing privileged information leakage caused by conditioning the teacher on y ? Standard OPSD exploits dense teacher distributions but is vulnerable to leakage. In this section, we provide a detailed theoretical analysis of DemoPSD from the perspectives of leakage attenuation and exploration preservation.

As we have analyzed in §4.1, in practice, we maintain a separate EMA copy of the student as the unprivileged reference, and construct the teacher based on the EMA copy for stability. Let π¯ denote this θ θ

EMA copy of the current student π . Throughout this section, both the privileged teacher distribution πT and π¯ on the corresponding privileged the student distribution S in the target are obtained by conditioning θ or unprivileged contexts. Following Yang et al. (2026), we define the per-step π squared magnitude of the privileged deviation: leakage rate as the expected

2]︀ t

∗

[︀ t

(14)

Rleak = Et ∥∆t∥ , where ∆t(v) = log πT(v, y ) − log πS(v).

In this definition, ∆t ∈ R its squared ℓ2 norm, measuring the total squared log-probability shift induced by y at position t. Throughout target θ ∗ πt(v):=π (v|x,yˆ )

<t for the student distribution at position , and target for the reverse-KL barycenter target defined in (9) with normalization constant αt in (11). Consequently, ∆t directly measures the influence of y on the model’s own prediction, rather than a discrepancy between two independent models. this section, we write θ

|V| 2 2 is a vector indexed by tokens in the vocabulary V, and ∥∆t∥ = v∈V ∆t(v) is ∗ t

Z

∑︀ παt

:= παt

# Theorem 1

. The effective leakage rate induced by DemoPSD satisfies: leak t t t

(Leakage Attenuation)

RDemoPSD := [︀(1 − )2∥ ∥2]︀ < leak

[︀∥ ∥2]︀=R

,

# Et

αt ∆t

Et ∆t where the strict inequality holds whenever Pr(α > 0) > 0. Moreover, the attenuation is strongest where leakage is monotonically increasing in d and d correlates positively with ∥ ∥ (both measure t t risk is greatest: since αt

∆t the divergence between πT and πS), positions with larger privileged deviation tend to receive larger αt and hence stronger suppression.

(15) selectively

(︀ t

∗ )︀1−αt (︀ t

Theorem 2 (Exploration Preservation). Let πtarget(v) ∝ πT(v, y ) be the reverse-KL barycenter target with the leakage attenuation coefficient αt ∈ [0, αmax], and write ∆t(v) = log π (v, y ) − log π (v) for the log-ratio. The full-teacher target minimized by SDPO is the special case α = 0, namely πt . Assume the privileged signal is positively aligned with the model’s own unprivileged prediction, i.e., πS (v)

)︀αt

Cov(,logt)≥0 tγ t1−γ πS qtγ ∆t

(16) undereverygeometricinterpolationqγ∝(πT)(πS) tributions. Then the DemoPSD target preserves strictly more entropy than the full-teacher target, with the t

, γ [0,1], between the student and teacher’s dis-

∈ ordering

H(t)≥H(αt )≥H(t), t ̸= t πS < πtarget πT

(17)

| holding with strict inequalities whenever 0 | αt and | πT | πT |
| --- | --- | --- | --- |
| 0 over the full-teacher target is non-decreasing | in α | t: the | more the teacher’s prediction depends on the privileged |
| ∗ |  |  |  |
| t γ | t γ | t | γ ( v ) , whi ch is an expo n entia l f amily with param- |
|  |  |  | [ log q t ] d [ f ] = Cov ( f , ∆ t ) |
|  |  |  | Eqtγγ and usingdγEqtγqtγ |

H( αt )−H( t)≥ πtarget

dH =−Covt( ,logqt) logqt =logπt +γ −logZ γ and expanding gives (18). Under condition (16), both terms are non-positive for γ > 0, so H(q ) is decreasing. Since 1 − αt < 1, the DemoPSD target 1 αt has strictly higher entropy than the OPSD target 1. Full proof is in Appendix A.2. t γ T S yields dγ

qγ ∆t

∆t γ . Substituting q − q

The result follows by tracking the entropy along the geometric path q ∝ (π ) (π ) unprivileged distribution ( 0 strictly short of the teacher. Along this path the entropy obeys t γ t 1−γ that connects the πtarget, q = t q = t q

= αt πS) to the full teacher ( 1 d H(qtγ ) dγ πT); the DemoPSD target sits at 1−αt

= − γ Varqt [∆t] − Covqt (∆t, log πS), γ γ t

(18) γ teacher is the same model which separates the entropy change into two terms. The first term γ of incorporating the privileged signal: any nonconstant multiplicative shift reduces entropy, and this cost grows with the . The second term ∗

−Cov t ( ,log πSt ) captures the interaction with the model’s existing predictions, and condition (16) requires their positive correlation: tokens to which the model already assigns qγ ∆t high probability receive a larger boost from y . This is the natural regime for self-distillation, where the with additional answer information and hence predominantly sharpens existing predictions rather than contradicting them. Because DemoPSD halts the interpolation at γ = 1 − < 1 rather than at the full teacher γ = 1, it never pays the final, steepest portion of this entropy cost; the entropy it saves grows with αt, consistent with the 33–98% entropy improvements over SDPO observed in Table 3.

− Var [ ] qtγ ∆t is the intrinsic entropy cost αt

- Table 2: Out-of-distribution generalization on GPQA Extended. Material science has no GPQA counterpart. Values are taken at the final training stage (mean over the last three evaluations). DemoPSD remains stable and improves slightly across all three GPQA domains, whereas SDPO degrades substantially over training

(Figure 3).

| Method | Biology | Chemistry | Physics | Average |
| --- | --- | --- | --- | --- |
| SD PO | 57.81 | 28.62 | 52.99 | 46.47 |
| Dem oPSD | 61.42 | 41.75 | 59.98 | 54.38 |

while down-weighting teacher signals that are likely to reflect privileged information on high-disagreement positions.

# 6. Experiments

We evaluate DemoPSD on scientific reasoning benchmarks, comparing against SDPO and GRPO as the primary baselines. The experiments focus on three aspects: in-domain accuracy, training entropy as an empirical indicator of exploration preservation, and out-of-distribution generalization as a proxy for reduced privileged information leakage.

# 6.1. Experimental Setup

Base Model. We use Qwen3-4B-Instruct (Qwen Team, 2025) as the base model for all experiments. Training Data. We train on SciKnowEval (Feng et al., 2024), a multi-domain scientific reasoning benchmark formulated as 4-choice multiple-choice questions. We train and evaluate separately on four domains: biology, chemistry, material science, and physics. Evaluation Benchmarks. We evaluate the performance on the following benchmarks to assess both in-domain accuracy and out-of-domain generalization:

# SciKnowEval

- (in-domain): Domain-matched test sets for each of the four scientific domains. (Rein et al., 2023) (out-of-domain): Graduate-level science questions in biology, chemistry, and physics. It is used to assess generalization beyond the training distribution.
- GPQA Extended

(a)
(b)

Validation accuracy (mean@16) on SciKnowEval over training steps. DemoPSD maintains higher accuracy than SDPO across training, with the largest margins observed in biology and physics.

Validation mean@16 vs. the sensitivity parameter baseline across β ∈ [25,100] β varies by domain. β per domain. The dashed line is the SDPO baseline. DemoPSD remains competitive with or above the SDPO

, while the optimal choice of

- Figure 2: (a) Validation accuracy curves across four domains of SciKnowEval. (b) Sensitivity to β.

Evaluation Metrics. For each test prompt, we sample 16 rollouts and report three complementary metrics that capture different aspects of model quality:

- mean@16
- : Average accuracy across 16 sampled rollouts. maj@16: Accuracy of the majority-voted answer across 16 rollouts. best@16: Best accuracy among 16 rollouts.
- Baselines. We compare DemoPSD against two baselines: (Shao et al., 2024): The standard RLVR baseline that estimates group-relative advantages from

# GRPO

- binary outcome rewards. (Hübotter et al., 2026): The on-policy self-distillation baseline. SDPO

All three methods use the same codebase, training infrastructure, base model, and training data, differing only in their optimization objectives: GRPO uses outcome-level reward, SDPO uses dense teacher supervision, and DemoPSD uses disagreement-modulated reverse-KL barycenter targets. −6

Hyperparameters. All methods share the following settings: learning rate 1 × 10 , batch size 64, 8 rollouts per prompt for training, max prompt length 2048, max response length 16384, 10 warmup steps, 3 training epochs. For distillation-based methods (SDPO and DemoPSD), we additionally use topEMA rate η = 0.05, and training temperature = 1.0 with validation temperature = 0.7. DemoPSD-specific parameters: αmax = 0.15. The sensitivity parameter β is tuned per domain (see §6.5). GRPO uses a KL penalty coefficient KL β = 0.04

k = 100 for distillation,

- Figure 3: Out-of-distribution generalization on GPQA Extended. Each panel tracks GPQA accuracy over training for one domain (material science has no GPQA counterpart). SDPO reaches its best OOD accuracy early and then degrades as training progresses, consistent with accumulating in-domain overfitting and privileged information leakage. In contrast, DemoPSD maintains stable OOD performance and achieves an improvement over training.

# 6.2. Main Results

- Table 1 reports the accuracy results across all four scientific domains. On average, DemoPSD improves over SDPO by 1.68 on mean@16, 1.68 on maj@16, and 2.82 on best@16. The best@16 improvement is notably larger, indicating that DemoPSD’s preserved exploration entropy surfaces higher-quality reasoning paths during sampling. Compared to GRPO, the total gain from DemoPSD is 5.21 on mean@16, demonstrating that the combination of dense supervision and selective adoption leads to substantial improvement.

- Figure 2a shows how the validation accuracy mean@16 changes with training steps. DemoPSD matches or outperforms SDPO throughout training, and the difference grows in later epochs. This agrees with our theoretical prediction that reducing leakage becomes more helpful as the student moves closer to the teacher’s distribution. Figure 1b reports the corresponding best@16 accuracy. The improvement is especially clear under best@16 and grows across training, indicating that the higher-entropy policy maintains broader solution coverage.

# 6.3. Out-of-Distribution Generalization

We evaluate the model’s out-of-distribution generalization capability on GPQA Extended dataset, which contains graduate-level science questions that differ substantially from SciKnowEval in format, difficulty, and question style. Table 2 reports the accuracy at convergence, and Figure 3 traces the full GPQA learning curves.

7.91

Although SDPO and DemoPSD start from comparable OOD accuracy, their performance evolves in substantially different directions over training (Figure 3). SDPO reaches its best OOD performance early, but subsequently degrades across all three GPQA domains; the largest drop occurs in chemistry, where accuracy decreases from 40.45 to 28.62. This mirrors the in-domain leakage-degradation pattern (§3.3): by collapsing onto the teacher, SDPO overfits the training distribution and loses the exploratory capacity necessary to transfer to novel questions. In contrast, DemoPSD maintains stable OOD accuracy throughout training and achieves a measurable improvement, ending above SDPO on average.

across all domains.

|  |  | Ent. | mean ¯ αt | mean d¯ | Active % |
| --- | --- | --- | --- | --- | --- |
|  | 0.602 | – | – | – |  |
| Dem oPSD | 0.816 | +35.5% | 0.055 | 0.046 | 64.8 |
| SD PO | 0.322 | – | – | – | – |
| Chemistry Dem oPSD | 0.555 | +72.4% | 0.036 | 0.037 | 84.0 |
| SD PO | 0.150 | – | – | – | – |
| Dem oPSD | 0.297 | +98.0% | 0.033 | 0.031 | 68.8 |
| SD PO | 0.385 | – | – | – | – |
| Dem oPSD | 0.511 | +32.7% | 0.040 | 0.026 | 90.6 |

Domain Method Entropy t

∆

Biology

| SDPO |  |  |  | – |
| --- | --- | --- | --- | --- |
| Dem | oPSD 0.511 | +32.7% | 0.040 | 90.6 0.026 |
| Table 4: Sensitivity to β ( | mean@16). All co | nfigurations use | αmax = 0.15 | . |
| β | Biology | Chemistry | Material | Physics |
| 15 | – | 71.93 | – | – |
| 25 | – | 72.98 | 76.46 | – |
| 50 | – | 71.90 | 76.53 | 70.55 |
| 70 | 39.25 | – | – | – |
| 100 | 36.88 | – | 76.06 | 71.64 |
| SD PO | 36.88 | 71.70 | 76.13 | 68.98 |

# 6.4. Training Dynamics

To understand how DemoPSD achieves its accuracy gains, we examine training dynamics, including entropy, disagreement, and hedging behavior at the final training step (Table 3). Entropy Preservation. DemoPSD maintains 33–98% higher final entropy than SDPO across all domains (Figure 1a). The largest entropy gap appears in material science (+98.0%), where SDPO’s entropy drops to 0.150, close to entropy collapse.

Disagreement Sparsity.

¯

The average leakage attenuation coefficient αt stays consistently low (0.033– 0.055), while the mean disagreement dt ranges from 0.026 to 0.046. These values indicate that the target remains close to the teacher distribution for most tokens, with strong attenuation applied only to a small subset of positions exhibiting substantial teacher-student disagreement. This pattern is consistent with the selective adoption principle: DemoPSD preserves the teacher signal on most tokens and applies disagreementmodulated attenuation only at positions where teacher and student’s predictions diverge.

¯

(a)
(b)

d

Distribution of per-token JSD disagreement t. Each panel shows one domain at the final training step. The exceed distribution is heavily right-skewed: the vast majority of tokens have near-zero disagreement, and only 2%-5%

0.25

.

DemoPSD dynamics over training. Mean leakage

attenuation coefficient t (blue, left axis) and mean JSD disagreement t (pink, right axis) over training batch per domain. Both quantities remain small and relatively α

d stable.

- Figure 4: Disagreement analysis of DemoPSD across four scientific domains.

# 6.5. Hyperparameter Sensitivity

The key hyperparameter of DemoPSD is β, which controls how sharply the leakage attenuation coefficient αt responds to disagreement. Table 4 shows the three best-performing β configurations for each domain.

Across the range β ∈ [25,100] robustness.

A general pattern emerges that domains where the disagreement is smaller (e.g., physics with mean ¯dt = 0.026) benefit from a higher β to amplify the weak disagreement signal, while domains with greater disagreement (e.g., biology with mean d¯t=0.046 β

) benefit from a lower to avoid over-aggressive hedging. , DemoPSD consistently matches or outperforms SDPO, demonstrating moderate

Remap vs. Threshold Mode. All top-performing configurations adopt the remapped alpha schedule in (8), which constrains αt to [0, αmax] and guarantees that the privileged teacher retains at least (1 − αmax) of the mixture weight. Figure 2b further illustrates how accuracy varies with β across domains.

# 6.6. Disagreement Analysis

To characterize how disagreement is distributed across tokens, we summarize statistics of the per-token disagreement t and leakage attenuation coefficient t for the best-performing DemoPSD run in each domain d α

(Table5).

d α

# 7. Conclusion

We introduced DemoPSD, a self-distillation framework based on selective adoption of teacher guidance: instead of forcing the student to imitate the privileged teacher at every token, DemoPSD constructs a reverseKL barycenter target that adaptively balances teacher guidance with the student’s own reasoning capacity. Our analysis shows that the disagreement-dependent barycenter weight directly modulates the teacherinduced signal in the training gradient: low-disagreement tokens retain dense teacher supervision, whereas high-disagreement tokens receive attenuated privileged guidance. We formalized this behavior through leakage attenuation and exploration preservation, showing how the proposed learning target reduces pressure to imitate privileged information while maintaining higher-entropy supervision. Empirically, DemoPSD improves over SDPO and GRPO across four scientific domains, maintains 35–98% higher training entropy, and generalizes robustly to out-of-distribution benchmarks.

# References

Rishabh Agarwal, Nino Vieillard, Yongchao Zhou, Piotr Stanczyk, Sabela Ramos Garea, Matthieu Geist, and Olivier Bachem. On-policy distillation of language models: Learning from self-generated mistakes. In

International Conference on Learning Representations, volume 2024, pages 21246–21263, 2024. DeepSeek-AI. Deepseek-r1: Incentivizing reasoning capability in llms via reinforcement learning. arXiv preprint arXiv:2501.12948, 2025.

DeepSeek-AI. Deepseek-v4: Towards highly efficient million-token context intelligence, 2026. Ken Ding. Hdpo: Hybrid distillation policy optimization via privileged self-distillation. arXiv preprint arXiv:2603.23871, 2026. Kehua Feng, Xinyi Shen, Weijie Wang, Xiang Zhuang, Yuqi Tang, Qiang Zhang, and Keyan Ding. Sciknoweval: Evaluating multi-level scientific knowledge of large language models. arXiv preprint arXiv:2406.09098,

2024.

In

Yuxian Gu, Li Dong, Furu Wei, and Minlie Huang. Minillm: Knowledge distillation of large language models. , volume 2024, pages 32694–32717, 2024.

International Conference on Learning Representations

Yinghui He, Simran Kaur, Adithya Bhaskar, Yongjin Yang, Jiarui Liu, Narutatsu Ri, Liam Fowl, Abhishek Panigrahi, Danqi Chen, and Sanjeev Arora. Self-distillation zero: Self-revision turns binary rewards into dense supervision. arXiv preprint arXiv:2604.12002

, 2026.

Jonas Hübotter, Frederike Lübeck, Lejs Behric, Anton Baumann, Marco Bagatella, Daniel Marta, Ido Hakimi, Idan Shenfeld, Thomas Kleine Buening, Carlos Guestrin, et al. Reinforcement learning via self-distillation. arXiv preprint arXiv:2601.20802, 2026.

models. arXiv preprint arXiv:2605.06597

, 2026.

Junlong Ke, Zichen Wen, Weijia Li, Conghui He, and Linfeng Zhang. Respecting self-uncertainty in on-policy self-distillation for efficient llm reasoning. arXiv preprint arXiv:2605.13255

, 2026.

Jeonghye Kim, Xufang Luo, Minbeom Kim, Sangmook Lee, Dohyung Kim, Jiwon Jeon, Dongsheng Li, and Yuqing Yang. Why does self-distillation (sometimes) degrade the reasoning capability of llms? arXiv preprint arXiv:2603.24472, 2026.

Jongwoo Ko, Sara Abdali, Young Jin Kim, Tianyi Chen, and Pashmina Cameron. Scaling reasoning efficiently via relaxed on-policy distillation. arXiv preprint arXiv:2603.11137

, 2026.

Gengsheng Li, Tianyu Yang, Junfeng Fang, Mingyang Song, Mao Zheng, Haiyun Guo, Dan Zhang, Jinqiao Wang, and Tat-Seng Chua. Unifying group-relative and self-distillation policy optimization via sample routing. arXiv preprint arXiv:2604.02288, 2026.

Kevin Lu and Thinking Machines Lab. On-policy distillation. Thinking Machines Lab: Connectionism, 2025. Qwen Team. Qwen3 technical report. David Rein, Betty Li Hou, Asa Cooper Stickland, Jackson Petty, Richard Yuanzhe Pang, Julien Dirani, Julian arXiv preprint arXiv:2505.09388

, 2025.

Michael, and Samuel R Bowman. Gpqa: A graduate-level google-proof q&a benchmark. arXiv preprint arXiv:2311.12022, 2023. Stéphane Ross, Geoffrey Gordon, and Andrew Bagnell. A reduction of imitation learning and structured prediction to no-regret online learning. In Proceedings of the Fourteenth International Conference on Artificial Intelligence and Statistics, 2011. Hejian Sang, Yuanda Xu, Zhengze Zhou, Ran He, Zhipeng Wang, and Jiachen Sun. Crisp: Compressed reasoning via iterative self-policy distillation. arXiv preprint arXiv:2603.05433, 2026. Zhihong Shao, Peiyi Wang, Qihao Zhu, Runxin Xu, Junxiao Song, Xiao Bi, Haowei Zhang, Mingchuan Zhang,

YK Li, Yang Wu, et al. Deepseekmath: Pushing the limits of mathematical reasoning in open language models. arXiv preprint arXiv:2402.03300, 2024.

Idan Shenfeld, Mehul Damani, Jonas Hübotter, and Pulkit Agrawal. Self-distillation enables continual learning. arXiv preprint arXiv:2601.19897, 2026.

Donghyeok Shin, Yeongmin Kim, Suhyeon Jo, Byeonghu Na, and Il-Chul Moon. Amid: Knowledge distillation for llms with α-mixture assistant distribution. In The Fourteenth International Conference on Learning Representations, 2026.

Mingyang Song and Mao Zheng. A survey of on-policy distillation for large language models. arXiv preprint arXiv:2604.00626, 2026. Alex Stein, Furong Huang, and Tom Goldstein. Gates: Self-distillation under privileged context with consensus gating. arXiv preprint arXiv:2602.20574

, 2026.

Zhiquan Tan and Yinrong Hong. Paint: Partial-solution adaptive interpolated training for self-distilled reasoners. arXiv preprint arXiv:2604.26573, 2026.

Yuanda Xu, Hejian Sang, Zhengze Zhou, Ran He, and Zhipeng Wang. Paced: Distillation and on-policy self-distillation at the frontier of student competence. arXiv preprint arXiv:2603.11178, 2026. Chenxu Yang, Chuanyu Qin, Qingyi Si, Minghui Chen, Naibin Gu, Dingyu Yao, Zheng Lin, Weiping Wang,

Jiaqi Wang, and Nan Duan. Self-distilled rlvr. arXiv preprint arXiv:2604.03128, 2026. Kai Yang, Xin Xu, Yangkun Chen, Weijie Liu, Jiafei Lyu, Zichuan Lin, Deheng Ye, and Saiyong Yang. Entropic: Towards stable long-term training of llms via entropy stabilization with proportional-integral control. arXiv preprint arXiv:2511.15248, 2025.

Qiying Yu, Zheng Zhang, Ruofei Zhu, Yufeng Yuan, Xiaochen Zuo, Yu Yue, Weinan Dai, Tiantian Fan, Gaohong Liu, Lingjun Liu, et al. Dapo: An open-source llm reinforcement learning system at scale. Advances in

Neural Information Processing Systems, 38:113222–113244, 2026a.

Xin Yu, Liuchen Liao, Yiwen Zhang, Yingchen Yu, Lingzhou Xue, and Qinzhen Guo. Preference-based self-distillation: Beyond kl matching via reward regularization. arXiv preprint arXiv:2605.05040

, 2026b.

Hongbin Zhang, Chaozheng Wang, Kehai Chen, Youcheng Pan, Yang Xiang, Jinpeng Wang, and Min Zhang. Tailoring teaching to aptitude: Direction-adaptive self-distillation for llm reasoning. arXiv preprint arXiv:2605.22263, 2026.

Siyan Zhao, Zhihui Xie, Mengchen Liu, Jing Huang, Guan Pang, Feiyu Chen, and Aditya Grover. Self-distilled reasoner: On-policy self-distillation for large language models. arXiv preprint arXiv:2601.18734, 2026.

# A. Detailed Proofs

# A.1. Complete Proof of Theorem

∥ ∥2 to ∆t

Proof. We fix a token position t and suppress the expectations over x and yˆ for clarity. Recall the notation: ∗ ∗ ∗ t t t t θ θ T T S θ S θ ∗ π (v) = πθ(v | x,yˆ<t), π (v,y ) = π¯(v | x,y ,yˆ<t), π (v) = π¯(v | x,yˆ<t), and ∆t(v) = logπ (v,y )− log πt (v)

.

Following Yang et al. (2026), the leakage at position is driven by the ∇ component that carries y -dependent information and pushes the student to encode privileged correlations. In standard OPSD, this term enters with coefficient 1, yielding a per-position leakage contribution proportional 2 2 (1 − αt) ∥∆t∥ . t

. In DemoPSD, the same term enters with coefficient

[ ] θEπt ∆t term, which is the

(1 − ) αt , yielding per-position contribution

Sinceαt=(σ(β·dt)−0.5)·2·αmax>0wheneverdt>0,wehave(1−αt)<1onallpositionswith nonzero disagreement. Taking expectations over positions: DemoPSD 2 2 2 2 2 2

2]︀

Rleak

= Et (1 − αt) ∥∆t∥ =Pr(dt=0)·E ∥∆t∥ |dt=0 +Pr(dt>0)·E (1−αt) ∥∆t∥ |dt>0 <Pr(dt=0)·E ∥∆t∥ |dt=0 +Pr(dt>0)·E ∥∆t∥ |dt>0 = Et ∥∆t∥ = Rleak, t t t

[︀

[︀ [︀

]︀ ]︀

[︀ [︀

]︀

]︀

[︀

2]︀

(1− )2<1 {d >0} αt where the strict inequality uses 2

, which has positive probability by assumption. Since αt is monotonically increasing in dt and dt = JSD(πS∥πT) correlates with ∥∆t∥, the attenuation factor (1 − αt) is smallest at positions with the largest ∥∆t∥, concentrating the suppression where it is most needed. on

(19)

Proof. t

We fix a token position , using the same notation as in Appendix A.1. t t (v) γ S t

Step1:Exponentialfamilystructure.Writeq (v)=π (v)eγ∆t

(v)=log t(v,y∗)−log t(v) πT πS partition function and ∆t parameter γ, sufficient statistic ∆t(v), and base measure πS. S S q (v) = πt (v)

At the boundary values: 0 corresponds to γ and 1

= αt

=1−αt,so 1−αt q πtarget.

/ZγwhereZγ= . This is a one-parameter exponential family with

∑︀ v π (v) eγ ∆t S t

(v) is the q (v) = πt (v)e∆t(v)/Z = πt (v, y ) 1 T

∗ . The DemoPSD target

Standard exponential family identities give: d log Z dγ γ=[],

Eqtγ ∆t d2 log Z 2

dγ

A key property we will use: for any function f : V → R, d Eqt[f] = Covqt(f, ∆t). γ γ

dγ t γ

Step 2: Entropy derivative. Since log q (v) = log π (v) + γ ∆t(v) − log Zγ, the entropy is: S t t t γ γ γ t

H(qγ) = −Eqt [log qγ] = −Eqt [log πS] − γ Eqt [∆t] + log Zγ. γ=Var[ ]≥0. qtγ ∆t

(20)

(21)

(22)

Differentiating each term with respect to γ: d (︀ − [ γ t])︀=−

Eqt log πS

Covqt γ

dγ d (︀ − dγ

[ ])︀=−

γ Eqtγ ∆t

Eqtγ ∆t dlogZγ= t[ ].

dγ

Eqγ ∆t t

( logπS, ∆t ,

)

[]−Var[], γ qtγ ∆t f = log t πS and (24) uses the product rule and (21) with

(23) uses (21) with the Eqt [∆t] terms cancel such that γ t d H(qγ ) dγ

=−Cov(,logt)−Var[]. qtγ ∆t πS γ qtγ ∆t

(23)

(24)

(25) f =

∆t. Summing (23)–(25),

(26) non-positive for

Step 3: Monotonicity under the covariance condition. Under condition (16), both terms in (26) are γ > 0

:

−Var[]≤0 γ

, with strict inequality when γ by the condition. S qtγ ∆t qγ ∆t t dγ

- −Covt( ,logπt)≤0

Hence d H(qγ) ≤

0 for all γ [0,1], with strict inequality on (0,1] when πT = πS. t t α t target αt S

∈

Step 4: Entropy ordering. Since H(qγ) is strictly decreasing on [0,1] when πT ̸= πS: t T

H(π ) = H(q0) > H(q1− ) = H(π t t ̸= t

\> 0 and ∆t is nonconstant (i.e., πT πS); t ̸ t t

) > H(q1) = H(π ),

(27) where the strict inequalities require 0 < αt < 1 (so that 0 < 1 − αt < 1, placing the DemoPSD target strictly between the two endpoints) and T πt ̸= πt

S.

# B. Implementation Details

Top-k Distillation. We extract top-k = 100 tokens from the student’s logits, compute both teacher probabilities on this same subset, and aggregate remaining mass into a tail bucket. This reduces memory from O(|V|) per position. The student’s top- indices are shared with both teacher forwards, ensuring all three distributions are index-aligned. to

O(k) k

Probability Floor.

All teacher log-probabilities are clamped: numerical issues in the geometric mixture computation. log p(v) ← max(log p(v), log 10−8 ) to prevent

Importance Sampling Clip. To stabilize training across PPO minibatches, we clip the importance sampling old ratio: ρ = min(exp(log πθ (yt ) − log πθ (yt )), 2.0).

EMA Schedule. The unprivileged reference uses EMA rate η complete within a training step.

Masking.

T

=

0.05, updated once after all minibatches

Only response tokens are included in the loss ( excludes prompt tokens). Samples without a valid reprompt (demopsd_mask = 0) have their loss contribution zeroed.

Privileged Context Truncation. When the privileged prompt (question + response) exceeds the maximum reprompt length (10,240 tokens), the demo the right, preserving the system/user prefix. This is a deliberate departure fro behavior, ensuring training proceeds even with long demonstrations. correct nstratio m SDPO solution is trun error-o

+ student cated from n-overflow n ’s
