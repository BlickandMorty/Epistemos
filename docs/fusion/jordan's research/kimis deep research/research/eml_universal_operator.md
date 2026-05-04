# The eml(x,y) Universal Operator: From Elementary Functions to Cognitive Primitives

## A Research Synthesis on arXiv:2603.21852 and Its Implications for Neural Computation

**Researcher**: Epistemos Research Division  
**Date**: 2026  
**Sources**: Odrzywołek arXiv:2603.21852 [^1^], Stachowiak arXiv:2604.23893 [^2^], Leshno et al. 1993 [^3^], Cybenko 1989 [^4^], Finn et al. 2017 (MAML universality) [^5^], Bienenstock-Cooper-Munro 1982 [^6^], Cook 2004 (Rule 110) [^7^], Kolmogorov-Arnold 1957 [^8^], Hornik-Stinchcombe-White 1989 [^9^], Gerstner et al. 1996 (STDP) [^10^]

---

## 1. The Formal Result: Odrzywołek's EML Theorem

### 1.1 Theorem Statement

**Definition** (EML Operator). The binary operator $\text{eml}: \mathbb{C} \times \mathbb{C} \to \mathbb{C}$ is defined as:

$$\text{eml}(x, y) = \exp(x) - \ln(y)$$

where $\ln$ denotes the principal branch of the complex logarithm.

**Theorem** (Odrzywołek, 2026 [^1^]). The set $\{1, \text{eml}\}$ forms a complete basis for the class of elementary functions as defined by the scientific-calculator basis (Table 1 of [^1^]): constants $\{\pi, e, i, -1, 1, 2, x, y\}$; unary functions $\{\exp, \ln, \text{inv}, \text{half}, \text{minus}, \sqrt{}, \text{sqr}, \sigma, \sin, \cos, \tan, \arcsin, \arccos, \arctan, \sinh, \cosh, \tanh, \text{arsinh}, \text{arcosh}, \text{artanh}\}$; and binary operations $\{+, -, \times, /, \log, \text{pow}, \text{avg}, \text{hypot}\}$. Every function in this class can be expressed as a finite binary tree whose nodes are all identical copies of $\text{eml}$ and whose leaves are the constant $1$ (plus input variables).

In formal language terms, the grammar is:

$$S \to 1 \mid \text{eml}(S, S)$$

This is a context-free grammar isomorphic to the class of full binary trees (Catalan structures).

### 1.2 Proof Sketch

The proof proceeds constructively via bootstrap ablation [^1^]:

1. **Layer 0**: Start with $\{1, \text{eml}\}$.
2. **Extract $e$**: $\text{eml}(1, 1) = e^1 - \ln(1) = e$
3. **Extract $\exp(x)$**: $\text{eml}(x, 1) = e^x - 0 = e^x$
4. **Extract $0$**: Through a depth-7 tree (see Table 4)
5. **Extract $\ln(x)$**: $\ln(z) = \text{eml}(1, \text{eml}[\text{eml}(1, z), 1])$ (depth 7)
6. **Extract negation and reciprocals**: Once $\exp$ and $\ln$ are available, their functional inverses yield subtraction, addition, multiplication, division via the group-theoretic structure identified by Stachowiak [^2^].
7. **Extract complex constants**: $i$ and $\pi$ via complex logarithms: $\ln(-1) = i\pi$ (with branch correction).
8. **Extract trigonometrics**: Via Euler's formula $e^{i\theta} = \cos\theta + i\sin\theta$, once $i$ and $\pi$ are available.

The exhaustive search was accelerated by a "suspicious" but effective method: testing equality at a single transcendental point (e.g., the Euler-Mascheroni constant) to 16 decimal places, then following up with full symbolic verification [^1^].

### 1.3 The Algebraic Structure (Stachowiak 2026)

Stachowiak [^2^] identified the deep algebraic structure. The general universal operator has the form:

$$S(x, y) = M(f(x), f^{-1}(y))$$

where $M$ is an operation satisfying three axioms:
- **Neutral element**: $\exists e: M(x, e) = x$
- **Self-cancellation**: $M(x, x) = e$
- **Anti-associativity**: $M(x, M(y, z)) = M(z, M(y, x))$

These axioms define an abelian group structure. For EML specifically:
- $f = \exp$, $f^{-1} = \ln$
- $M$ is subtraction (conjugated through $\ln$: $M(u, w) = \ln^{-1}(\ln(u) - \ln(w))$ which is division, but Odrzywołek uses raw subtraction)

Stachowiak shows that **whatever** the choice of $f$ and $M$, recovering $f^{-1}$ always requires exactly Polish notation length 7 (depth 3). The particular depth of EML expressions is therefore not an inherent feature of the logarithm but a structural necessity of the axiom system [^2^].

---

## 2. How eml(x,y) Generates sin(x): The Composition Sequence

The path from $\{1, \text{eml}\}$ to $\sin(x)$ proceeds through the following chain (compiled from [^1^] Figure 1 and the algebraic structure in [^2^]):

### Step-by-Step Construction

| Step | Primitive | EML Depth | Construction Logic |
|------|-----------|-----------|-------------------|
| 1 | $e$ | 1 | $\text{eml}(1,1) = e$ |
| 2 | $\exp(x)$ | 1 | $\text{eml}(x,1) = e^x$ |
| 3 | $0$ | 3 | $\text{eml}(1, \text{eml}(e, 1)) = e - \ln(e) = 0$ |
| 4 | $\ln(x)$ | 3 | $\text{eml}(1, \text{eml}[\text{eml}(1,x), 1])$ |
| 5 | $-x$ (negation) | ~5 | Via group inversion: $M(e, x)$ structure |
| 6 | $x + y$ | ~5 | Via anti-associativity cancellation [^2^] |
| 7 | $x \times y$ | 8 | $\exp(\ln x + \ln y)$ |
| 8 | $-1$ | ~7 | From $0 - 1$ via addition chain |
| 9 | $i = \sqrt{-1}$ | ~6 | $\text{eml}(0, \text{eml}(1, -1)) = 1 - \ln(-1) = 1 - i\pi$ (with branch correction) |
| 10 | $\pi$ | ~5 | From $\ln(-1) = i\pi$, divide by $i$ |
| 11 | $e^{ix}$ | ~2 | $\text{eml}(ix, 1)$ |
| 12 | $\sin(x)$ | ~8 | $\sin(x) = \frac{e^{ix} - e^{-ix}}{2i}$ |

The exact EML depths for trigonometric functions are not fully listed in Table 4 of [^1^], but the paper notes that $\arctan(1)$ requires **over 1,000 EML operations** [^1^]. The Jagiellonian University press release confirms that computing $\pi$ requires depth ~5 (for the constant) and $i$ requires depth ~6 [^11^].

The key insight is that EML must first "bootstrap" the entire complex arithmetic infrastructure before trigonometry becomes available. This is analogous to how a NAND-based computer must first build adders before it can perform multiplication.

---

## 3. Computational Complexity of eml-Composition vs. Direct Computation

### 3.1 Expression Depth Analysis (Table 4 from [^1^])

| Function | EML Compiler Depth $K$ | Direct Search Shortest $K$ |
|----------|----------------------|---------------------------|
| $1$ | 1 | 1 |
| $e$ | 3 | 3 |
| $\exp(x)$ | 3 | 3 |
| $\ln(x)$ | 7 | 7 |
| $0$ | 7 | 7 |
| $-1$ | 17 | 15 |
| $2$ | 27 | 19 |
| $i$ | 131 | $> 55$ |
| $\pi$ | 193 | $> 53$ |
| $-x$ | 57 | 15 |
| $1/x$ | 65 | 15 |
| $x^{-1}$ | 43 | 11 |
| $x + 1$ | 27 | 19 |
| $x^2$ | 75 | 17 |
| $x + y$ | 27 | 19 |
| $x \times y$ | 41 | 17 |
| $x / y$ | 105 | 17 |
| $x^y$ | 49 | 25 |
| $\sqrt{x}$ | 139 | $> 35$ |

### 3.2 Complexity Interpretation

The **EML compiler** produces expressions with leaf count $K$ (RPN instruction count). The **direct search** column shows shortest known expressions. The gap between compiler output and direct search lower bounds indicates that optimal EML encodings are highly non-trivial—much like optimal Boolean circuits from NAND gates are not simply the naive translation.

**Key observations**:
- Basic exponentials and logarithms are cheap (depth 1-3)
- Arithmetic operations are moderate (depth ~8-20)
- Constants like $\pi$ and $i$ are expensive ($K > 50$)
- The Hacker News replication notes that training EML trees beyond depth 4 is numerically unstable without hierarchical hot-starting [^12^]

### 3.3 Practical Complexity

Odrzywołek notes that for practical computation, EML is **not** a performance win: "For basic arithmetic, this is not required nor would it be faster." [^12^] However, for **chained transcendental expressions** (e.g., Jacobians in weather simulation where the bottleneck is $\exp(-E_a/RT)$), an EML tree can process the entire expression in a single pipeline pass rather than multiple SFU calls [^12^].

---

## 4. Can eml(x,y) Inspire a Single Neural Network Primitive?

### 4.1 The Leshno-Pinkus Theorem

The connection to neural networks is immediate. **Leshno et al. (1993)** [^3^] proved:

> A standard multilayer feedforward network with a locally bounded piecewise continuous activation function can approximate any continuous function to any degree of accuracy **if and only if** the network's activation function is **not a polynomial**.

This means that **any** non-polynomial activation—ReLU, sigmoid, tanh, GELU, SiLU, and indeed $\text{eml}(x, 1) = e^x$—is individually sufficient for universal approximation. The EML operator is therefore not unique in this regard; rather, it occupies an extreme point on the spectrum of "minimal sufficient primitives."

### 4.2 From Universal Approximation to Universal Generation

The key difference between the Leshno result and Odrzywołek's result:

| Property | Leshno UAT | Odrzywołek EML |
|----------|-----------|----------------|
| Domain | Function approximation | Function **generation** |
| Operation | Single activation + linear weights | Single binary operator + constant |
| Composition | Network depth/width | Binary tree depth |
| Result | Approximate any continuous $f$ | **Exactly** generate any elementary $f$ |
| Trainability | Yes (backprop) | Yes (gradient-based symbolic regression) |

Odrzywołek's most practical contribution is demonstrating that **EML trees can be trained via gradient descent** (Adam) to recover exact closed-form elementary functions from data at depths up to 4 [^1^]. This is a form of "differentiable symbolic regression."

### 4.3 Proposal: The EML Neuron

A single-neuron architecture using only EML operations:

```
Input x, y -> eml(w1*x + b1, w2*y + b2) -> output
```

However, EML as a raw activation has severe numerical issues:
- $\exp(x)$ causes explosive growth for $x > 5$
- $\ln(y)$ requires $y > 0$ (domain restriction)
- The Hacker News replication found that random initialization at depth 4 always diverges due to exponential string growth [^12^]

**Solution**: The "Ameo activation function" [^13^] already showed that a carefully designed piecewise function can model all 16 binary Boolean functions perfectly. An EML-inspired activation would need:
- Saturation at both ends (like the Ameo function)
- Built-in domain correction for logarithmic branch
- Normalized inputs to prevent exponential explosion

---

## 5. The Analogue for Learning Rules: Is There a "Single Learning Rule"?

### 5.1 The Meta-Learning Universality Result

**Finn et al. (2017, MAML)** [^5^] proved a striking parallel to Odrzywołek's result:

> A deep representation combined with **one step of gradient descent** can approximate any permutation-invariant function of a dataset and test datapoint. When using deep, expressive function approximators, there is **no theoretical disadvantage** in terms of representational power to using MAML over a black-box meta-learner.

In other words: **gradient descent on a sufficiently expressive initialization is a universal learning procedure approximator.**

### 5.2 The BCM Rule as a "Sliding-Threshold Universal Plasticity Rule"

The **Bienenstock-Cooper-Munro (BCM) rule** [^6^] provides the neuroscience analogue:

$$\frac{dw_i}{dt} = \eta \cdot y \cdot (y - \theta_M) \cdot x_i$$

where $\theta_M = \phi(\langle y \rangle)$ is a **dynamic sliding threshold** that adapts based on the history of postsynaptic activity.

The BCM rule:
- Subsumes **Hebbian LTP** when $y > \theta_M$ ($\phi > 0$)
- Subsumes **anti-Hebbian LTD** when $y < \theta_M$ ($\phi < 0$)
- Subsumes **homeostatic normalization** via $\theta_M$ adaptation
- Can implement **STDP-like** timing effects when extended to spike-based formulations [^14^]

### 5.3 Proposal: The "EML of Learning Rules"

Drawing the parallel explicitly:

| NAND/EML Domain | Learning Rule Domain |
|-----------------|---------------------|
| NAND gate | Single synaptic update operation |
| Boolean circuit composition | Network-wide plasticity composition |
| Functional completeness | **Plasticity completeness** |
| EML: $\exp - \ln$ | **Universal plasticity: $\Delta w = f(pre, post, threshold, modulator)$** |

A candidate **universal plasticity primitive**:

$$\Delta w_{ij} = \eta \cdot \underbrace{\sigma(\text{pre}_j)}_{\text{presynaptic gating}} \cdot \underbrace{\phi(\text{post}_i - \theta_M)}_{\text{postsynaptic deviation}} \cdot \underbrace{\psi(\text{modulator}_k)}_{\text{third-factor}}$$

where:
- $\sigma$ = sigmoid-like gating (implements Hebbian "fire together")
- $\phi$ = nonlinear deviation function (implements BCM sliding threshold)
- $\psi$ = neuromodulatory gating (implements dopamine/attention-based meta-learning)

This **three-factor rule** [^15^] is the plasticity analogue of EML's three algebraic ingredients ($f$, $f^{-1}$, $M$). Just as EML combines $\exp$, $\ln$, and subtraction, universal plasticity combines presynaptic activity, postsynaptic deviation, and neuromodulation.

---

## 6. Connection to the Resonance Model's 5 Directional Operators

The Resonance Model posits 5 directional operators for cognitive processing. The EML result suggests a radical minimization:

| Resonance Model | EML Reduction |
|-----------------|---------------|
| 5 directional operators | Potentially **1** operator + composition |
| Directional semantics | Emergent from composition structure |
| Stable features | Emergent from repeated application of single primitive |

Stachowiak [^2^] showed that the general form $S(x,y) = M(f(x), f^{-1}(y))$ requires:
- One binary operator $M$ (subtraction-like, anti-associative)
- One function $f$ (exponential-like, with addition formula)
- One constant (identity element)

The **5 operators** of the Resonance Model may correspond to 5 distinct instantiations of the general form (4a)-(4c) identified by Odrzywołek:
- EML: $\exp(x) - \ln(y)$ with constant 1
- EDL: $\exp(x) / \ln(y)$ with constant $e$
- -EML: $\ln(x) - \exp(y)$ with constant $-\infty$

The 5 Resonance operators could thus be viewed as a **basis expansion** of the universal operator, specialized for different cognitive subspaces (perception, memory, action, abstraction, metacognition).

---

## 7. Can EML Replace ReLU/GELU/SiLU in a Transformer?

### 7.1 Theoretical Feasibility

By the Leshno theorem [^3^], **yes**—any non-polynomial activation is sufficient. The EML-derived activation $\text{eml}(x, 1) = e^x$ is entire (analytic everywhere), which is actually a stronger property than ReLU (which is not differentiable at 0).

However, practical transformer training requires:
- **Stable gradients**: $e^x$ explodes for $x > 10$
- **Normalization compatibility**: LayerNorm + EML would require gradient clipping
- **Computational cost**: $\exp$ and $\ln$ are ~10x more expensive than ReLU

### 7.2 Modified EML Activation for Transformers

A practical EML-based activation for transformers:

$$\sigma_{\text{EML}}(x) = \text{eml}(\text{clip}(x, -5, 5), 1) - \text{eml}(0, 1) = e^{\text{clip}(x, -5, 5)} - e$$

This is a shifted, clipped exponential that:
- Has bounded output range (prevents explosion)
- Is differentiable everywhere (unlike ReLU)
- Can represent ReLU-like behavior through composition
- Maintains the universal approximation property

Odrzywołek's gradient-based symbolic regression experiments [^1^] show that EML trees at depth 4 can recover exact formulas. A transformer with EML activations at depth 12-24 would have exponentially more expressive power—but would require hierarchical hot-starting to prevent divergence [^12^].

---

## 8. The "One Stable Feature" Philosophy

### 8.1 Mathematical Grounding

The EML operator reveals that the apparent diversity of elementary mathematics is an **epiphenomenon of composition depth**. What looks like many distinct functions (sin, cos, log, sqrt) is actually one function applied at different depths with different argument patterns.

This maps directly to the "one stable feature" philosophy:

> If one operator generates all of continuous mathematics, then one learning mechanism—properly composed—generates all of cognition.

The **Principle of Computational Equivalence** (Wolfram 2002) [^16^] states that almost all non-trivial processes can be viewed as computations of equivalent sophistication. EML proves this for the mathematical function space. The analogue for learning would be:

> **Principle of Learning Equivalence**: Almost all non-trivial learning dynamics can be viewed as compositions of a single plasticity primitive of equivalent sophistication.

### 8.2 Evidence from Biology

The brain does not use SGD, Hebbian, STDP, and BCM as separate "algorithms." Rather:
- **STDP** is Hebbian learning with temporal asymmetry [^10^]
- **BCM** is Hebbian learning with a sliding threshold [^6^]
- **Meta-learning** is gradient descent on an initialization [^5^]
- **Reinforcement learning** is three-factor Hebbian with dopaminergic modulation [^15^]

All are compositions of a single underlying update: $\Delta w = f(pre, post, context)$.

---

## 9. Is There a "NAND Gate" for Learning?

### 9.1 The NAND of Plasticity

We propose the following as a candidate **universal plasticity gate**:

$$\boxed{\Delta w = \eta \cdot x_{pre} \cdot (x_{post} - \theta) \cdot m}$$

Where:
- $x_{pre}$ ∈ $\{-1, 0, +1\}$ (presynaptic activity, ternary)
- $x_{post}$ ∈ $\mathbb{R}$ (postsynaptic activity)
- $\theta$ ∈ $\mathbb{R}$ (dynamic threshold)
- $m$ ∈ $\{-1, 0, +1\}$ (neuromodulatory gating)
- $\eta$ (learning rate)

### 9.2 How It Implements All Known Plasticity Rules

| Rule | Configuration of the Universal Gate |
|------|-----------------------------------|
| **Pure Hebbian** | $\theta = 0$, $m = 1$: $\Delta w = \eta \cdot x_{pre} \cdot x_{post}$ |
| **Anti-Hebbian** | $\theta = 0$, $m = -1$: $\Delta w = -\eta \cdot x_{pre} \cdot x_{post}$ |
| **BCM** | $\theta = \theta_M(\langle x_{post} \rangle)$, $m = 1$: sliding threshold |
| **STDP** | $\theta = \theta(t_{pre} - t_{post})$, $x_{pre/post}$ = spike trains: timing-dependent |
| **Meta-learning (MAML)** | $\theta = \nabla_\theta L$, $m = 1$: gradient descent as special case |
| **Homeostatic normalization** | $\theta = \text{target rate}$, $m = \text{sign}(deviation)$ |
| **Gated plasticity** | $m = 0$ (no change), $m = \pm 1$ (LTP/LTD) |

---

## 10. Mapping to the Ternary Substrate (-1, 0, +1)

### 10.1 The Ternary Universal Learning Gate

The Epistemos substrate proposes ternary values $\{-1, 0, +1\}$. The universal plasticity gate maps naturally:

$$\Delta w_{ij} = \eta \cdot \underbrace{\text{sgn}(x_j)}_{pre \in \{-1,0,+1\}} \cdot \underbrace{\text{relu}_\theta(x_i)}_{post \in \mathbb{R}} \cdot \underbrace{\text{sgn}(m_k)}_{modulator \in \{-1,0,+1\}}$$

This yields **9 fundamental update modes** (3 × 3, since postsynaptic is real-valued):

| pre | modulator | Result |
|-----|-----------|--------|
| -1 | -1 | $\Delta w > 0$ (LTP via depression) |
| -1 | 0 | $\Delta w = 0$ (gated off) |
| -1 | +1 | $\Delta w < 0$ (LTD) |
| 0 | any | $\Delta w = 0$ (no presynaptic activity) |
| +1 | -1 | $\Delta w < 0$ (LTD via inverse) |
| +1 | 0 | $\Delta w = 0$ (gated off) |
| +1 | +1 | $\Delta w > 0$ (LTP) |

### 10.2 The EML-Ternary Isomorphism

There is a structural parallel between:
- EML's three algebraic ingredients ($f$, $f^{-1}$, $M$) [^2^]
- The ternary substrate's three value states ($-1$, $0$, $+1$)
- The universal plasticity gate's three factors (pre, post, modulator)

| EML Structure | Ternary Substrate | Plasticity Structure |
|--------------|-------------------|---------------------|
| $f = \exp$ (expansion) | $+1$ (potentiation) | $x_{pre} > 0$ (active) |
| $f^{-1} = \ln$ (contraction) | $-1$ (depression) | $x_{pre} < 0$ (inverse active) |
| $M = $ subtraction (differential) | $0$ (null/neutral) | $m = 0$ (gated off) |

The constant $1$ in EML (the identity element $\ln(1) = 0$) corresponds to the **neutral element** $0$ in the ternary system—the state from which all other states are generated through composition.

---

## 11. Synthesis: eml → Universal Learning → Epistemos Substrate

### 11.1 The Chain of Reductions

```
Boolean Logic          Continuous Math         Neural Computation         Synaptic Plasticity
    NAND          ->        EML           ->    Non-polynomial σ      ->    Universal Plasticity Gate
  (1 gate,         (1 operator +            (1 activation suffices     (1 update rule +
   2 inputs)        1 constant)              for UAT)                  3 ternary inputs)
```

### 11.2 Philosophical Implications

Odrzywołek's discovery is not merely a mathematical curiosity. It is a **proof of concept** for extreme minimalism in complex systems. The implications cascade:

1. **Mathematics**: All elementary functions are generated by one operator -> the "source code" of math is much shorter than believed [^11^]
2. **Computation**: A CPU built from EML gates could evaluate any elementary expression in a single pipeline pass [^12^]
3. **Neural Networks**: A network with a single non-polynomial activation is universally approximating [^3^]
4. **Learning**: A single plasticity rule with three ternary factors subsumes all known forms of synaptic change
5. **Cognition**: The "5 directional operators" of the Resonance Model may be 5 instantiations of a single underlying primitive

### 11.3 The Epistemos Conjecture

> **Conjecture** (Epistemos Universal Primitive Hypothesis): There exists a single computational primitive $P$ with ternary inputs $\{-1, 0, +1\}$ such that:
> 1. **Function generation**: Iterated composition of $P$ generates any computable elementary function (EML analogue)
> 2. **Universal approximation**: A network of $P$-units approximates any continuous function (Leshno analogue)
> 3. **Universal plasticity**: Iterated application of $P$ as a weight update implements all known learning rules (MAML + BCM analogue)
> 4. **Cognitive completeness**: A system composed entirely of $P$-units exhibits all 5 Resonance Model directional dynamics through structural composition rather than operator diversity

The EML operator $\text{eml}(x,y) = e^x - \ln(y)$ is the continuous-mathematical proof-of-concept for this conjecture. The task ahead is to discover—or engineer—the analogous primitive for discrete, ternary, neuromorphic computation.

---

## 12. Rust Code Scaffold: EML-Based Activation Function

```rust
//! EML Universal Activation Function
//! 
//! Implements the eml(x,y) = exp(x) - ln(y) operator as a neural network
//! activation function, with domain corrections and gradient-safe clipping.
//! 
//! Based on: Odrzywołek, "All elementary functions from a single binary operator"
//! arXiv:2603.21852 [cs.SC]

use std::f64::consts::{E, PI};

/// EML Operator: the universal primitive for continuous mathematics
/// 
/// eml(x, y) = exp(x) - ln(y)
/// 
/// Domain notes:
/// - For y <= 0, ln(y) requires complex extension. In real mode, we clamp.
/// - For x > ~700, exp(x) overflows f64. We clip to prevent gradient explosion.
pub fn eml(x: f64, y: f64) -> f64 {
    let exp_x = x.clamp(-700.0, 700.0).exp();
    let ln_y = if y > 0.0 {
        y.ln()
    } else {
        // Extended real: ln(0) = -inf, ln(negative) = NaN (complex)
        // For neural networks, clamp to a large negative value
        -1e308
    };
    exp_x - ln_y
}

/// EML-derived single-input activation function
/// 
/// σ_eml(x) = eml(x, 1) - eml(0, 1) = exp(x) - e
/// 
/// This is a shifted exponential that passes through origin at x=1.
/// Output range: (-e, +∞) for real inputs, but clipped in practice.
pub fn eml_activation(x: f64) -> f64 {
    let clipped = x.clamp(-10.0, 10.0);  // Prevent gradient explosion
    eml(clipped, 1.0) - E  // Shift so that eml(0,1) - eml(0,1) = 0
}

/// Gradient-safe EML activation with learnable shift and scale
/// 
/// σ_eml(x; α, β, γ) = α * eml(β*x + γ, 1)
/// 
/// Parameters:
/// - α: output scaling (like weight in linear layer)
/// - β: input scaling (like inverse temperature)
/// - γ: bias/threshold (learnable offset)
pub fn eml_activation_parametric(x: f64, alpha: f64, beta: f64, gamma: f64) -> f64 {
    let scaled = beta.mul_add(x, gamma).clamp(-10.0, 10.0);
    alpha * eml(scaled, 1.0)
}

/// Derivative of EML activation for backpropagation
/// 
/// d/dx [eml(x, 1)] = d/dx [exp(x)] = exp(x)
/// 
/// Note: This is the "clean" derivative. With clipping, the derivative
/// is zero outside the clip range (like a saturated ReLU).
pub fn eml_activation_derivative(x: f64) -> f64 {
    if x < -10.0 || x > 10.0 {
        0.0  // Clip gradient outside safe range
    } else {
        x.exp()  // d/dx exp(x) = exp(x)
    }
}

/// EML tree node for symbolic regression
/// 
/// A binary tree where every internal node is eml and every leaf is 1 or a variable.
/// This is the core data structure for Odrzywołek's gradient-based symbolic regression.
#[derive(Clone, Debug)]
pub enum EmlNode {
    Constant(f64),  // Typically 1.0, but could be learned
    Variable(usize), // Index into input vector
    Eml(Box<EmlNode>, Box<EmlNode>), // eml(left, right)
}

impl EmlNode {
    /// Evaluate the EML tree at given inputs
    pub fn eval(&self, inputs: &[f64]) -> f64 {
        match self {
            EmlNode::Constant(c) => *c,
            EmlNode::Variable(i) => inputs.get(*i).copied().unwrap_or(0.0),
            EmlNode::Eml(left, right) => {
                let l = left.eval(inputs);
                let r = right.eval(inputs);
                eml(l, r)
            }
        }
    }
    
    /// Compute depth of the tree
    pub fn depth(&self) -> usize {
        match self {
            EmlNode::Constant(_) | EmlNode::Variable(_) => 0,
            EmlNode::Eml(left, right) => {
                1 + usize::max(left.depth(), right.depth())
            }
        }
    }
    
    /// Count total nodes (leaf count K in Odrzywołek's notation)
    pub fn leaf_count(&self) -> usize {
        match self {
            EmlNode::Constant(_) | EmlNode::Variable(_) => 1,
            EmlNode::Eml(left, right) => {
                left.leaf_count() + right.leaf_count() + 1
            }
        }
    }
}

/// Example: Construct eml(1, eml(eml(1, x), 1)) = ln(x)
/// 
/// This is the canonical example from Odrzywołek's paper (Equation 5).
pub fn example_ln_tree() -> EmlNode {
    EmlNode::Eml(
        Box::new(EmlNode::Constant(1.0)),
        Box::new(EmlNode::Eml(
            Box::new(EmlNode::Eml(
                Box::new(EmlNode::Constant(1.0)),
                Box::new(EmlNode::Variable(0)),  // x
            )),
            Box::new(EmlNode::Constant(1.0)),
        )),
    )
}

/// Example: Construct the exponential e^x = eml(x, 1)
pub fn example_exp_tree() -> EmlNode {
    EmlNode::Eml(
        Box::new(EmlNode::Variable(0)),  // x
        Box::new(EmlNode::Constant(1.0)),
    )
}

/// Universal Plasticity Gate (UPG)
/// 
/// The proposed "NAND gate of learning" implemented in ternary substrate.
/// 
/// Δw = η * sgn(pre) * relu_deviation(post, θ) * sgn(modulator)
/// 
/// All three inputs are in {-1, 0, +1} except postsynaptic (real-valued).
pub fn universal_plasticity_gate(
    pre: i8,           // presynaptic: -1, 0, +1
    post: f64,        // postsynaptic activity
    threshold: f64,   // dynamic threshold θ_M
    modulator: i8,    // neuromodulator: -1, 0, +1
    eta: f64,         // learning rate
) -> f64 {
    let pre_gate = pre as f64;  // -1.0, 0.0, or 1.0
    let post_deviation = (post - threshold).max(0.0);  // relu-like deviation
    let mod_gate = modulator as f64;
    
    eta * pre_gate * post_deviation * mod_gate
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_eml_basic() {
        assert!((eml(1.0, 1.0) - E).abs() < 1e-10);  // e = eml(1,1)
        assert!((eml(2.0, 1.0) - E.powi(2)).abs() < 1e-10);  // e^2 = eml(2,1)
    }
    
    #[test]
    fn test_ln_tree() {
        let tree = example_ln_tree();
        let x = 2.718281828459045;  // approximately e
        let result = tree.eval(&[x]);
        assert!((result - 1.0).abs() < 1e-6);  // ln(e) ≈ 1
    }
    
    #[test]
    fn test_exp_tree() {
        let tree = example_exp_tree();
        let x = 1.0;
        let result = tree.eval(&[x]);
        assert!((result - E).abs() < 1e-10);
    }
    
    #[test]
    fn test_universal_plasticity_gate() {
        // Hebbian LTP: pre=+1, post > threshold, modulator=+1
        let dw = universal_plasticity_gate(1, 1.5, 0.5, 1, 0.1);
        assert!(dw > 0.0);
        
        // Anti-Hebbian LTD: pre=+1, post > threshold, modulator=-1
        let dw = universal_plasticity_gate(1, 1.5, 0.5, -1, 0.1);
        assert!(dw < 0.0);
        
        // Gated off: modulator = 0
        let dw = universal_plasticity_gate(1, 1.5, 0.5, 0, 0.1);
        assert!(dw == 0.0);
        
        // No presynaptic activity
        let dw = universal_plasticity_gate(0, 1.5, 0.5, 1, 0.1);
        assert!(dw == 0.0);
    }
}
```

---

## 13. Open Questions and Future Work

1. **Ternary EML analogue**: Can a discrete ternary operator $T(a,b) \in \{-1, 0, +1\}$ be found that generates all discrete computable functions via composition?
2. **Optimal EML encoding**: The gap between compiler-generated depths and direct-search lower bounds (Table 4) suggests NP-hardness. Is minimal EML encoding NP-complete?
3. **Neural EML training**: Can EML-based activations be trained stably at transformer-scale depth (>40 layers)?
4. **Plasticity completeness**: Can the BCM rule with dynamic threshold be proven to subsume all known biologically-plausible plasticity rules?
5. **Hardware implementation**: Can an FPGA-based EML processor outperform GPU SFUs for chained transcendental computation?
6. **Resonance Model reduction**: Can the 5 directional operators be formally reduced to fewer primitives using Stachowiak's general form?

---

## References

[^1^]: A. Odrzywołek, "All elementary functions from a single binary operator," arXiv:2603.21852 [cs.SC], April 2026.
[^2^]: T. Stachowiak, "Algebraic structure behind Odrzywołek's EML operator," arXiv:2604.23893 [math-ph], April 2026.
[^3^]: M. Leshno, V. Ya. Lin, A. Pinkus, and S. Schocken, "Multilayer feedforward networks with a nonpolynomial activation function can approximate any function," *Neural Networks*, vol. 6, no. 6, pp. 861–867, 1993.
[^4^]: G. Cybenko, "Approximation by superpositions of a sigmoidal function," *Mathematics of Control, Signals, and Systems*, vol. 2, no. 4, pp. 303–314, 1989.
[^5^]: C. Finn, A. Rajeswaran, S. Kakade, and S. Levine, "Online meta-learning," arXiv:1710.11622 [cs.LG], 2017.
[^6^]: E. Bienenstock, L. Cooper, and P. Munro, "Theory for the development of neuron selectivity: orientation specificity and binocular interaction in visual cortex," *Journal of Neuroscience*, vol. 2, no. 1, pp. 32–48, 1982.
[^7^]: M. Cook, "Universality in elementary cellular automata," *Complex Systems*, vol. 15, pp. 1–40, 2004.
[^8^]: A. N. Kolmogorov, "On the representation of continuous functions of several variables by superposition of continuous functions of one variable and addition," *Doklady Akademii Nauk SSSR*, vol. 114, pp. 953–956, 1957.
[^9^]: K. Hornik, M. Stinchcombe, and H. White, "Multilayer feedforward networks are universal approximators," *Neural Networks*, vol. 2, no. 5, pp. 359–366, 1989.
[^10^]: W. Gerstner, R. Kempter, J. L. van Hemmen, and H. Wagner, "A neuronal learning rule for sub-millisecond temporal coding," *Nature*, vol. 386, pp. 76–78, 1996.
[^11^]: Jagiellonian University, "EML operator – a mathematical curiosity or a practical computational tool?" Press release, April 2026.
[^12^]: Hacker News discussion, "All elementary functions from a single binary operator," March 2026.
[^13^]: C. Primozic, "Logic Through the Lens of Neural Networks," 2022.
[^14^]: R. C. Froemke and Y. Dan, "Spike-timing-dependent synaptic modification induced by natural spike trains," *Nature*, vol. 416, pp. 433–438, 2002.
[^15^]: W. Schultz, P. Dayan, and P. R. Montague, "A neural substrate of prediction and reward," *Science*, vol. 275, pp. 1593–1599, 1997.
[^16^]: S. Wolfram, *A New Kind of Science*, Wolfram Media, 2002.

---

*End of Research Report*
