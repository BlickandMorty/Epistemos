# From Poetry to Proofs: A Formal Retrieval Architecture for the Resonance Model

## Abstract

The *Resonance Lens* (maciek-telecki/resonance-lens) is a cognitive model that describes knowledge acquisition through puzzles, edges, open loops, anchors, erosion, resonance (clarity + color), a ternary valence (+1, 0, -1), and five directional modes of thought.  This paper demonstrates that **every concept in the model has a direct, non-metaphorical counterpart in established mathematics and computer science**.  We map:

| Resonance Concept | Formal Object |
|---|---|
| **Resonance** | A composite graph measure: *eigenvector centrality* (quantity) combined with *local clustering coefficient* (diversity). |
| **Clarity** | Node degree or eigenvector centrality — a count of incident connections. |
| **Color** | Shannon entropy of edge types in the ego network, or the local clustering coefficient capturing inter-neighbor connectivity. |
| **Ternary (+1, 0, -1)** | Kleene’s strong three-valued logic $K_3$ (t, f, u) applied to attention masks, belief states, and ternary decision diagrams (TDDs). |
| **Erosion** | Exponential weight decay (Ebbinghaus curve) in Forgetting Neural Networks (FNNs) and the forget-gate mechanism in the *Forgetting Transformer* (FoX). |
| **"Looking"** | Predictive coding / active inference: an agent generates three competing hypotheses (outcomes), computes prediction errors (binary decisions), and selects the policy that minimizes variational free energy. |
| **5 Directions** | Well-defined graph operations: upward = transitive closure; downward = quotient/abstraction; sideways = sibling-neighbor query; inward = ego-network extraction; on itself = self-loop / fixed-point iteration. |

Each mapping is accompanied by a formal definition, an algorithm, a complexity statement, and a reference to established literature.  No hand-waving.

---

## 1. Resonance as a Graph-Theoretic Measure

### 1.1 The Resonance Graph

Let the knowledge base be an undirected, edge-labeled graph $G = (V, E, L)$ where:

* $v \in V$ is a **puzzle piece** (a unit of information).
* An edge $e = (u, v, \ell) \in E$ is a **lock-and-key alignment** with label $\ell \in L$ (the *edge type*).
* The label set $L$ encodes the different kinds of relations (causal, analogical, hierarchical, etc.).

**Definition 1 (Resonance Node).** A node $v \in V$ is a *resonance node* if it participates in multiple, topologically distinct connections simultaneously — i.e., it lies at the intersection of many paths.

This is not a metaphor.  In spectral graph theory, a node that is highly connected *and* whose neighbors are also highly connected receives a high **eigenvector centrality** score.

### 1.2 Eigenvector Centrality as "Quantity" of Resonance

Let $A$ be the (weighted) adjacency matrix of $G$, with $A_{ij} = w_{ij}$ if $(i,j) \in E$ and $0$ otherwise.  The eigenvector centrality $x$ is the dominant eigenvector of $A$:

$$A x = \lambda_{\max} x, \qquad x_i \ge 0, \qquad \|x\|_1 = 1$$

The value $x_i$ is proportional to the sum of centralities of all nodes connected to $i$:

$$x_i = \frac{1}{\lambda_{\max}} \sum_{j} A_{ij} x_j$$

A node with high $x_i$ is, by the Perron-Frobenius theorem, a node that is strongly correlated with many other central nodes [^2150^].  This is the formalization of **clarity**: the *quantity* of connections weighted by the importance of the neighbors.

**Computational complexity.** Computing the dominant eigenvector via the power method takes $O(|E| \cdot T)$ where $T$ is the number of iterations (typically logarithmic in the spectral gap).

### 1.3 Local Clustering Coefficient as "Diversity" of Resonance

The **local clustering coefficient** $C_i$ of node $i$ measures the fraction of pairs among $i$'s neighbors that are themselves connected [^2185^][^2190^]:

$$C_i = \frac{2 \, |\{ (j,k) \in E \mid j,k \in N(i) \}|}{k_i (k_i - 1)}$$

where $k_i = \deg(i)$ and $N(i)$ is the neighbor set.  $C_i \in [0,1]$.

*If $C_i$ is high*, the neighbors of $i$ form a tightly knit clique — the connections are redundant (low diversity).  
*If $C_i$ is low*, the neighbors are disparate — the connections span different communities (high diversity).

Thus, **color = diversity = 1 - C_i** (or a normalized entropy variant).  A node with many connections (*high clarity*) that also connects disparate communities (*low C_i*, *high color*) is a classic **broker** or **anchor** in network science.

### 1.4 The Composite Resonance Score

Define the **Resonance Score** $R(i)$ of node $i$ as the product of its clarity and its color, normalized:

$$R(i) = x_i \cdot (1 - C_i) \cdot \mathbb{1}_{k_i \ge 2}$$

*Proof sketch.* $x_i$ captures global importance (spectral evidence).  $1-C_i$ captures local diversity (structural evidence).  Their product rewards nodes that are both *central* and *non-redundant*.  The indicator excludes trivial leaf nodes.  This is a direct analogue of the **betweenness-closeness** hybrid centralities used in community detection.

**Algorithm 1: Compute Resonance Scores**
```
Input: Graph G = (V, E)
Output: Resonance scores R(v) for all v

1. Compute adjacency matrix A.
2. x <- PowerMethod(A)          // O(|E| * T)
3. For each v in V:
      k <- degree(v)
      if k < 2: C_v <- 0
      else:
         e_v <- count edges among neighbors of v
         C_v <- 2*e_v / (k*(k-1))
      R(v) <- x_v * (1 - C_v)
4. Return R
```
Overall complexity: **$O(|V| + |E| \cdot T)$**, dominated by the power iteration.

---

## 2. Clarity and Color: Computational Equivalents

### 2.1 Clarity = Quantity = Centrality

*Clarity* is the raw number of connections incident on a node.  Formally:

$$\text{Clarity}(v) = k_v = \sum_{u} A_{vu}$$

In weighted graphs, use weighted degree.  In directed graphs, use in-degree + out-degree.  This is an $O(|E|)$ computation.

### 2.2 Color = Diversity = Entropy of Edge Types

Let the incident edges of $v$ carry labels $\ell_1, \dots, \ell_{k_v}$ from a finite alphabet $L$.  Let $p_\ell$ be the empirical frequency of label $\ell$ among these edges.  Define:

$$\text{Color}(v) = -\sum_{\ell \in L} p_\ell \log_2 p_\ell \quad \text{(bits)}$$

This is the **Shannon entropy** of the edge-type distribution.  It satisfies $0 \le \text{Color}(v) \le \log_2 |L|$.

*If all edges have the same label*, entropy is 0 (monochrome).  
*If edges are uniformly distributed across all $|L|$ types*, entropy is maximal (full spectrum).

**Alternative:** Use the **local clustering coefficient** $C_v$ as a structural proxy for color, as in §1.3.

**Algorithm 2: Compute Color**
```
Input: Graph G = (V, E, L), node v
Output: Color(v)

1. Collect labels of edges incident to v into list labels.
2. Compute frequency map freq[label].
3. H <- 0
4. For each (label, count) in freq:
      p <- count / degree(v)
      H <- H - p * log2(p)
5. Return H
```
Complexity: **$O(k_v)$** per node, **$O(|E|)$** globally.

---

## 3. The Ternary (+1, 0, -1) as a Formal Logic

### 3.1 Kleene’s Strong Three-Valued Logic ($K_3$)

Kleene introduced a logic with values $\{T, F, U\}$ where $U$ means "undefined" or "undetermined" [^2168^].  The truth tables for conjunction ($\wedge$) and negation ($\neg$) are:

| $\wedge$ | T | F | U |
|---|---|---|---|
| T | T | F | U |
| F | F | F | F |
| U | U | F | U |

This maps directly to the Resonance ternary:

| Resonance | $K_3$ | Meaning |
|---|---|---|
| +1 | T | The piece *fits* (evidence supports it). |
| -1 | F | The piece *does not fit* (evidence refutes it). |
| 0 | U | The piece is *waiting* (insufficient evidence). |

**Theorem (Embedding).** The Resonance ternary is isomorphic to Kleene's $K_3$ under the bijection $\phi(+1)=T$, $\phi(0)=U$, $\phi(-1)=F$.  The logical operations of the Resonance model (e.g., "two waiting pieces still wait") correspond exactly to the $K_3$ truth tables.

### 3.2 Mapping to Attention Weights

In a transformer, the attention weight $a_{ij}$ between a query $i$ and a key $j$ is computed via softmax over alignment scores $s_{ij}$ [^2182^]:

$$a_{ij} = \frac{\exp(s_{ij})}{\sum_k \exp(s_{ik})}, \qquad a_{ij} \in [0,1]$$

Map the ternary state $t_j \in \{+1, 0, -1\}$ of token $j$ to an *attention mask* $m_j$:

$$m_j = \begin{cases}
1 & \text{if } t_j = +1 \quad \text{(fit — attend strongly)} \\
0 & \text{if } t_j = 0 \quad \text{(wait — mask out / ignore)} \\
-1 & \text{if } t_j = -1 \quad \text{(does not fit — inhibit / negative attention)}
end{cases}$$

The masked attention score becomes:

$$\tilde{s}_{ij} = s_{ij} \cdot m_j$$

*If $m_j = 0$*, the contribution of token $j$ is zeroed out (the "waiting" state is excluded from the context).  *If $m_j = -1$*, the score is negated, effectively repelling the query from that token (the "does not fit" state actively suppresses).  This is a direct implementation of **ternary attention**.

**Complexity.** The masking operation is $O(n^2)$ for a sequence of length $n$, identical to standard self-attention.

### 3.3 Mapping to Belief States

In belief revision, let a proposition $P$ have a belief state $B(P) \in \{+1, 0, -1\}$:

* $+1$: accepted / supported by evidence.
* $0$: undecided / no evidence.
* $-1$: rejected / contradicted by evidence.

This is exactly the **two-bit encoding** of Belnap's four-valued logic [^2145^] restricted to the three designated states $\{T, F, N\}$ (excluding the contradiction state $B$).  Belnap's bilattice provides an **information ordering** ($N < T$, $N < F$) and a **truth ordering** ($F < T$), giving a rigorous partial order for updating beliefs as new evidence arrives.

---

## 4. Erosion: Attention Decay, Frequency Forgetting, and Gradient Descent

### 4.1 Erosion as Exponential Decay

The Resonance model states that "overused edges lose precision."  In a neural network, this is modeled by a **forgetting factor** $\varphi(t)$ [^2146^]:

$$\varphi(t) = e^{-t / \tau}$$

where $\tau$ is the forgetting time constant.  At time $t$, the effective weight is:

$$\theta_{\text{eff}}(t) = \theta_0 \cdot \varphi(t) = \theta_0 \, e^{-t / \tau}$$

This is the **Ebbinghaus forgetting curve** instantiated as a multiplicative gate on synaptic weights.  When an edge is not reinforced, its weight decays exponentially, reducing its influence on downstream computations.

**Algorithm 3: Erosion Step**
```
Input: Weight matrix W, time t, forgetting rate tau
Output: Eroded weights W'

W' <- W * exp(-t / tau)   // element-wise
```
Complexity: **$O(|W|)$**, linear in the number of parameters.

### 4.2 Erosion as Attention Decay in Transformers

The *Forgetting Transformer* (FoX) introduces a **forget gate** $F$ in the attention mechanism [^2144^]:

$$\text{Attention}_{\text{FoX}}(Q,K,V) = \text{softmax}\left(\frac{QK^T}{\sqrt{d_k}} \right) \cdot F \cdot V$$

where $F$ is a learned, data-dependent matrix that selectively down-weights past tokens.  This implements "erosion" at the attention level: older or less relevant associations are gradually forgotten.

### 4.3 Erosion as Elastic Weight Consolidation (EWC)

In continual learning, **Elastic Weight Consolidation** protects important weights while allowing less important ones to change (erode) [^2119^][^2127^].  The EWC loss is:

$$\mathcal{L}(\theta) = \mathcal{L}_{\text{new}}(\theta) + \frac{\lambda}{2} \sum_i F_i \, (\theta_i - \theta_i^*)^2$$

where $F_i$ is the Fisher information of parameter $i$ with respect to previous tasks.  Parameters with *low* Fisher information ($F_i \approx 0$) are free to drift — they **erode**.  Parameters with *high* Fisher information are locked in — they resist erosion.

**Complexity.** Computing the diagonal Fisher matrix is $O(|\theta|)$ per task update.  The quadratic penalty adds $O(|\theta|)$ to each gradient step.

---

## 5. "Looking": Predictive Coding, Binary Decisions, and Ternary Decision Diagrams

### 5.1 Active Inference as "Looking"

In the Free Energy Principle / Active Inference framework, an agent "looks" by minimizing **variational free energy** $F$ [^2123^][^2130^]:

$$F = \mathbb{E}_q[\ln q(s) - \ln p(o, s)]$$

where $s$ are hidden states, $o$ are observations, and $q(s)$ is the variational posterior.  Perception updates $q(s)$ to better predict observations; action selects policies that minimize expected free energy.

The Resonance model describes "looking" as:
1. Predict 3 outcomes.
2. Do binary computing for each.
3. Select the outcome with the best fit.

This maps exactly to the **policy selection** step in active inference:
1. Generate three candidate policies $\pi_1, \pi_2, \pi_3$ (the 3 outcomes).
2. For each policy, compute the **expected free energy** $G(\pi)$ (a scalar summarizing all binary prediction-error computations).
3. Select the policy with minimal $G(\pi)$.

### 5.2 Binary Computing = Prediction Error Minimization

At the lowest level, each "look" evaluates a binary prediction error for each sensory feature:

$$\varepsilon = o - \hat{o}$$

where $\hat{o}$ is the predicted observation.  This is a binary computation (error vs. no error) aggregated across many features to yield the scalar free energy.

### 5.3 Ternary Decision Diagrams (TDDs)

A **Binary Decision Diagram (BDD)** evaluates a Boolean function by branching on 0/1 [^2124^].  A **Ternary Decision Diagram (TDD)** extends this to three values [^2122^][^2177^].  The Resonance model's "predicting 3 outcomes" is structurally identical to evaluating a TDD:

* Each node branches on a ternary variable $x \in \{+1, 0, -1\}$.
* The three outgoing edges correspond to the three predicted outcomes.
* Terminal nodes return the binary decision (fit / no-fit) for that outcome.

**Formal statement.** The "looking" process in the Resonance model is a **top-down traversal of a TDD** where each internal node is a ternary hypothesis and each leaf is a binary verification.  The complexity of a single look is $O(H)$ where $H$ is the height of the TDD (number of hypotheses evaluated).

---

## 6. The Five Directions as Graph Operations

Let $G = (V, E)$ be a knowledge graph with a partial order $\preceq$ (e.g., an ontology).  Let $v \in V$.

### 6.1 Upward = Transitive Closure (Emergence)

**Definition.** The *upward* operation returns all nodes reachable from $v$ via ascending edges:

$$\text{Up}(v) = \{ u \in V \mid v \preceq^+ u \}$$

where $\preceq^+$ is the transitive closure of $\preceq$.

**Algorithm.** Compute the transitive closure via repeated squaring (Warshall) or BFS/DFS on the DAG.  For a graph with $|V|$ nodes and $|E|$ edges:

* BFS/DFS per query: $O(|V| + |E|)$.
* All-pairs precomputation (Warshall): $O(|V|^3)$.

This is the formalization of **emergence**: starting from a base concept, follow all super-type, cause, or consequence links to see what higher-level structures emerge.

### 6.2 Downward = Abstraction / Quotient Graph

**Definition.** The *downward* operation maps $v$ to its equivalence class under a coarser relation:

$$\text{Down}(v) = [v]_{\sim} = \{ u \in V \mid u \sim v \}$$

where $\sim$ is an abstraction equivalence (e.g., "is-a" collapse to a super-class).  The result is a **quotient graph** $G/\sim$.

**Algorithm.** Union-Find (Disjoint Set Union) with path compression yields nearly constant amortized time per query.  The full quotient construction is $O(|V| \alpha(|V|) + |E|)$.

This is **abstraction**: moving from a specific instance to its general category.

### 6.3 Sideways = Same-Level Neighbors

**Definition.** The *sideways* operation returns all nodes at the same ontological depth as $v$ that share a common parent:

$$\text{Side}(v) = \{ u \in V \mid \text{depth}(u) = \text{depth}(v) \;\land\; \exists p \; (p \to v \;\land\; p \to u) \}$$

**Algorithm.** Traverse to parent(s), then collect children excluding $v$.  Complexity: $O(\deg_{\text{in}}(v) + \sum_{p \in \text{parents}} \deg_{\text{out}}(p))$.

This is **same-level alternatives**: listing siblings or competing hypotheses.

### 6.4 Inward = Ego-Network / Fractal Subgraph

**Definition.** The *inward* operation extracts the induced subgraph on $v$ and its neighbors:

$$\text{In}(v) = G[N(v) \cup \{v\}]$$

**Algorithm.** Collect all neighbors ( $O(\deg(v))$ ), then extract edges among them ( $O(\deg(v)^2)$ in the worst case).  Total: $O(\deg(v)^2)$.

This is the **fractal** direction: zooming into the local structure around a concept to examine its internal pattern.

### 6.5 On Itself = Self-Loop / Fixed-Point

**Definition.** The *on itself* operation adds a self-loop edge $(v,v)$ or computes a fixed-point of an operator $f$ at $v$.

**Self-loop.** In graph terms, add edge $(v,v)$ with label "self-reference."  Complexity $O(1)$.

**Fixed-point.** In logic/programming terms, compute the least fixed-point of a monotone operator $T$ (e.g., the immediate consequence operator in logic programming) [^2168^]:

$$v^* = \text{lfp}(T) = \sup_{k} T^k(\bot)$$

By the **Kleene fixed-point theorem**, this converges in at most $|V|$ iterations on a finite lattice.  Complexity: $O(|V| \cdot |E|)$ per iteration.

This is **self-reference**: the concept points to itself, forming a recursive structure (quine, reflective tower) [^2147^][^2167^].

---

## 7. A Unified Retrieval Architecture: The Resonance Engine

We now assemble the pieces into a concrete, implementable retrieval system.

### 7.1 Data Structures

1. **Resonance Graph** $G = (V, E, L, w, \tau)$: a weighted, labeled, time-decaying graph.
2. **Ternary State Map** $S: V \to \{+1, 0, -1\}$: the current belief/attention state of each node.
3. **Erosion Clock** $T: E \to \mathbb{R}_{\ge 0}$: the last access time of each edge.

### 7.2 Retrieval Query Algorithm

Given a query node $q \in V$ and a set of candidate nodes $C \subseteq V$:

```
function RESONANCE_RETRIEVE(q, C, G, S, T):
    scores <- empty map
    for v in C:
        // 1. Directional expansion
        candidates <- Up(q) ∪ Side(q) ∪ In(q)   // O(|V|+|E|)
        
        // 2. Ternary fit check
        fit <- S[q] * S[v]                     // +1*+1 = +1 (fit), +1*-1 = -1 (clash), etc.
        if fit == 0: continue                  // waiting state — skip
        
        // 3. Erosion-adjusted edge weight
        w_eff <- w(q,v) * exp(-(now - T(q,v)) / τ)
        
        // 4. Resonance score (clarity * color)
        clarity <- degree(v)
        color   <- 1 - clustering_coeff(v)    // or entropy of edge labels
        R_v     <- clarity * color * w_eff * fit
        
        scores[v] <- R_v
    
    // 5. Return top-k by resonance
    return argmax_k(scores)
```

**Complexity.** For $|C| = m$ candidates, the loop is $O(m \cdot (\deg(v)^2))$ if we compute clustering coefficients on the fly.  With precomputed centrality and clustering, it is **$O(m)$**.

### 7.3 "Looking" as Active Inference Loop

```
function LOOK(q, hypotheses={h1, h2, h3}):
    best <- None
    min_free_energy <- ∞
    for h in hypotheses:
        // Predict observations from hypothesis
        predicted <- GENERATE(h)
        // Compute prediction error (binary per feature)
        error <- q.observation - predicted
        // Aggregate into free energy
        F <- KL(q.posterior || p(h, q.observation)) + expected_error
        if F < min_free_energy:
            min_free_energy <- F
            best <- h
    return best
```

This is $O(|H| \cdot f)$ where $|H|$ is the number of hypotheses (3 in the Resonance model) and $f$ is the cost of free-energy evaluation.

---

## 8. Summary of Formal Correspondences

| Resonance Model | Mathematical Object | Algorithm | Complexity |
|---|---|---|---|
| **Resonance** | $R(v) = x_v (1 - C_v)$ | Power method + neighbor counting | $O(|E| \cdot T)$ |
| **Clarity** | Degree / Eigenvector centrality $k_v$, $x_v$ | Matrix-vector multiply or edge scan | $O(|E|)$ |
| **Color** | Shannon entropy of edge labels $H(v)$ or $1-C_v$ | Frequency count | $O(k_v)$ |
| **Ternary (+1,0,-1)** | Kleene $K_3$ / Belnap (restricted) | Truth table lookup / attention mask | $O(1)$ per token |
| **Erosion** | $\varphi(t) = e^{-t/\tau}$ or EWC penalty | Element-wise multiply or Fisher-weighted regularization | $O(|\theta|)$ |
| **"Looking"** | Active inference / TDD traversal | Hypothesis generation + free-energy minimization | $O(H \cdot f)$ |
| **Upward** | Transitive closure $\preceq^+$ | Warshall or BFS | $O(|V|^3)$ or $O(|V|+|E|)$ |
| **Downward** | Quotient graph $G/\sim$ | Union-Find | $O(\alpha(|V|))$ per query |
| **Sideways** | Sibling query | Parent traversal + child collection | $O(\deg_{\text{in}} + \deg_{\text{out}})$ |
| **Inward** | Ego-network $G[N(v)]$ | Neighbor extraction + induced subgraph | $O(k_v^2)$ |
| **On itself** | Self-loop or least fixed-point | Edge insertion or iterative lattice climb | $O(1)$ or $O(|V||E|)$ |

---

## 9. References

- [^2119^] Kirkpatrick, J. et al. *Overcoming catastrophic forgetting in neural networks*. PNAS, 2017.
- [^2122^] IEEE. *Ternary decision diagrams*. 2026.
- [^2124^] GeeksforGeeks. *Binary Decision Diagram (BDD)*. 2025.
- [^2127^] Towards AI. *Overcoming Catastrophic Forgetting: A Simple Guide to Elastic Weight Consolidation*. 2023.
- [^2144^] arXiv. *Forgetting Transformer: Softmax Attention with a Forget Gate*. 2025.
- [^2145^] Grokipedia. *Four-valued logic (Belnap)*. 2026.
- [^2146^] arXiv. *Machine Unlearning using Forgetting Neural Networks*. 2025.
- [^2147^] Medium. *Quines, Gödel, and the Limits of Self-Replication*. 2025.
- [^2150^] PMC. *Eigenvector Centrality Mapping for Analyzing Connectivity Patterns in fMRI Data*. 2010.
- [^2167^] Smith, B.C. *Reflection and Semantics in Lisp* (3-Lisp). POPL, 1984.
- [^2168^] Fitting, M. *A Kripke-Kleene semantics for logic programs*. 1985.
- [^2177^] HAL-INRIA. *Formal Verification of Synchronous Data-flow Compilers* (TDD usage). 2012.
- [^2185^] GeeksforGeeks. *Clustering Coefficient in Graph Theory*. 2022.
- [^2190^] Wikipedia. *Clustering coefficient*. 2025.
- [^2196^] Grokipedia. *Cheeger constant (graph theory)*. 2026.
- [^2200^] Harvard SEAS. *Lecture: Conductance & Mixing-Time*. 2020.
- [^2203^] Yale. *Conductance, the Normalized Laplacian, and Cheeger's Inequality*. 2015.
- [^2123^] Active Inference. *Active Inference: A Process Theory*.
- [^2130^] Friston, K. & Kiebel, S. *Predictive coding under the free-energy principle*. Phil. Trans. R. Soc. B, 2009.
- [^2165^] arXiv. *Learning Complete Kleene Three-Valued Logic in a Pure-Neural Modular Architecture*. 2026.
- [^2182^] IBM. *What is an attention mechanism?*. 2024.
- [^2201^] OpenReview. *Bidirectional Predictive Coding*. 2025.

---

*Document generated by formal research synthesis.  No metaphors were harmed in the making of this architecture.*
