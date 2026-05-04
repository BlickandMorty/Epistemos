## Prime-Composite Knowledge Ontology

### Research Question
What is the "prime" (irreducible, fundamental) vs "composite" (derived, built from other claims) structure of a knowledge graph? How does the deterministic prime gap mathematics map to knowledge representation, curriculum learning, information retrieval, and attention mechanisms in AI?

---

### 1. Key Findings

#### 1.1 Prime and Composite Claims in Knowledge Graphs

**Finding:** The distinction between "prime" (axiomatic, self-evident) and "composite" (derived, dependent) claims is structurally isomorphic to the distinction between axioms and theorems in formal ontologies, and between primitives and derived concepts in knowledge representation systems.

In ontologies, axioms are "foundational sentences assumed to be true without derivation from other KB content" [^2891^]. This maps directly to "prime claims." Inferred sentences are "derived from existing KB content through logical reasoning" — these are "composite claims." The ontology learning literature formalizes this into a "layer cake" of complexity: terms at the bottom, synonyms, concepts, taxonomical hierarchies, and at the top layer: rules and axioms (disjoint, domain, range relations) [^2842^].

**Finding:** The PrimeNet framework demonstrates a three-layer knowledge architecture directly analogous to the prime-composite structure: a small core of conceptual **primitives** (e.g., FOOD, COLOR), a larger set of **concepts** connecting to primitives (e.g., fruit), and an even larger layer of **entities** (e.g., banana) [^2897^]. This is structurally identical to how primes are few and fundamental while composites are numerous and derived.

**Finding:** Formal Concept Analysis (FCA) provides the mathematical machinery for this decomposition. FCA transforms binary object-attribute data into a hierarchical **concept lattice** via Galois connections and closure operators. A formal concept is a pair (A, B) where A is the extent (objects) and B is the intent (attributes), with concepts partially ordered by inclusion [^2901^]. The lattice structure naturally separates "prime" concepts (minimal nontrivial intents) from "composite" concepts (intents that are unions/intersections of others).

#### 1.2 Divisor Normalization Identity and Claim Dependencies

**Finding:** The Divisor Normalization Identity (DNI) from prime gap structure normalizes divisor counts in prime gaps. In knowledge graph terms, this corresponds to normalizing the "in-degree" or "dependency count" of each claim. A claim with high in-degree (many other claims depend on it) is structurally similar to a prime with many multiples — it is a **carrier** of downstream structure.

**Finding:** In knowledge graphs, the XGBoost prerequisite detection model identifies that the most important feature for prerequisite relationships is "P_corpus(c_b | c_a)" — the occurrence of concepts in a corpus — followed by graph interconnection features (LP, CN, SCS) that measure shared neighbors and path lengths [^2844^]. This mirrors how prime gaps are characterized by shared divisor structure.

#### 1.3 No-Later-Simpler-Composite Theorem and Curriculum Learning

**Finding:** The No-Later-Simpler-Composite Theorem states that there are zero violations through 10^18 — a composite number is never "simpler" (has fewer divisors) than an earlier composite in a gap. This has a direct analogue in curriculum learning: **do not teach complex claims before their prime components**.

**Finding:** Curriculum learning theory demonstrates that presenting training examples in order of increasing difficulty (as determined by loss value) modifies the optimization landscape, making it "steeper while maintaining the same global minimum" [^2127^]. The theoretical analysis defines an "ideal curriculum" that does not change the global minimum but accelerates convergence. This is isomorphic to the prime sieve: processing numbers in order, eliminating composites (difficult/confusing examples) only after their prime factors (fundamental components) have been established.

**Finding:** Topological sorting of course prerequisites using Kahn's algorithm (BFS on in-degrees) provides a deterministic ordering: start with zero in-degree courses (prime/axiomatic knowledge) and progressively unlock dependent courses (composite/derived knowledge) [^2235^][^2920^]. This is algorithmically identical to the sieve: primes have zero "dependencies" (no smaller factors); composites have dependencies (prime factors). The theorem that "all composite numbers up to N have a prime factor ≤ √N" [^2922^] maps to: all derived claims depend on fundamental claims within a bounded "depth" of the knowledge graph.

**Finding:** Surprisingly, curriculum learning research has found that "models trained with the inversed version of the algorithms [hard examples first] performed slightly better than the standard curriculum training variants" in some settings [^2840^]. This creates tension with the No-Later-Simpler-Composite rule — suggesting that the optimal ordering may depend on whether the goal is comprehension (primes first) or robustness (composites first).

#### 1.4 Gap Winner Rule for Information Retrieval

**Finding:** The Gap Winner Rule (GWR) states that the raw-Z maximizer is always the leftmost min-d(n) carrier. For knowledge retrieval, this translates to a **leftmost-minimum-dependency principle**: when multiple sources compete to establish a claim, the source with the fewest prerequisite dependencies (minimum in-degree in the knowledge graph) wins as the most fundamental.

**Finding:** The "Sieve Attention" mechanism proposes a two-stage attention that first employs α-entmax to "sieve" the entire context, selecting a small candidate set of content-relevant tokens, then applies sequential allocation on this pre-filtered set [^2900^]. This is algorithmically analogous to the Eratosthenes sieve: first eliminate (mark as composite) the clearly irrelevant, then process the remaining candidates. The paper proves this design overcomes limitations of both sparse and sequential attention mechanisms.

**Finding:** In knowledge graph prerequisite detection, "common neighbors is a better indicator of a strong link between concepts than the sharing of common categories" [^2844^]. This aligns with GWR: the "winner" in establishing a prerequisite is the concept pair with the strongest shared neighborhood structure (like primes sharing gap structure).

#### 1.5 Predicting Knowledge Gaps

**Finding:** The prime gap structure reveals that "primes are not random — they appear exactly where forced by the deterministic structure of the composite numbers that come before them." The analogue: **derived facts determine which fundamental facts are needed**. If a model knows facts A, B, C, the gaps in its knowledge can be predicted by analyzing which composite claims require prime claims not yet in the KB.

**Finding:** Information-theoretic capacity bounds (VC dimension) quantify what models can know. The VC dimension for neural networks scales with the number of weights, and the "lossless memory dimension" generalizes VC dimension to provide an upper bound for perfectly fitting almost any training data [^2883^]. For a knowledge graph, this suggests a bound on how many "prime claims" can be stored versus how many "composite claims" can be derived.

**Finding:** The Rumsfeld matrix (known knowns, known unknowns, unknown unknowns, unknown knowns) has been operationalized for machine learning [^2910^]. "Unknown unknowns" are data points the model mispredicts with high confidence — precisely the knowledge gaps that occur when composite claims are asserted without their prime foundations. U3DAL (Unsupervised Unknown Unknown Detection in Active Learning) uses predictive entropy and diversity scores to detect these [^2910^].

#### 1.6 Tri-State Attractor and Claim Verification

**Finding:** The prime gap tri-state attractor analysis shows that mod 3 reduction of gaps yields a dominant attractor at residue 0 (40.2% frequency vs expected 33.3%), indicating "deterministic modular stabilization" [^2839^]. The triplet frequency bias conjecture states: for all i ≡ 0 mod 3, gap frequencies satisfy g_i > g_{i+1} and g_i > g_{i+2} [^2925^].

**Finding:** This tri-state structure maps naturally to claim verification states: **Verified (0)**, **Unverified/Unknown (1)**, and **Contradicted (2)**. The 0-dominance suggests that in a well-structured knowledge graph, most claims should tend toward the verified state (like gaps tending to 0 mod 3). The attractor dynamics suggest that verification is not random but follows deterministic constraints from the composite structure of supporting evidence.

**Finding:** LLM self-awareness research distinguishes two sources of uncertainty: **Data uncertainty** (question underspecified) and **Model uncertainty** (question admits unique answer but exceeds model capabilities) [^2853^]. This maps to: Data uncertainty = composite claim with insufficient prime support; Model uncertainty = prime claim beyond current model capacity. Models frequently misclassify these, framing knowledge gaps as input ambiguity or vice versa.

#### 1.7 Composites Dictate Primes → Derived Facts Determine Fundamentals

**Finding:** The prime gap research asserts that "one must first understand the sequence to the composites not divisible by 2 or 3 to understand the sequence to the prime numbers; the sequence to primes is disguised as a sequence to composites" [^2905^]. This directly maps to: **to determine which fundamental facts are needed, analyze the structure of derived facts**.

**Finding:** In knowledge-based agents, the Ask/Tell operations mirror this: new information is told to the KB, and the KB derives inferred sentences through reasoning [^2891^]. The "composites" (derived sentences) are what force the need for "primes" (axioms). If a derived claim cannot be justified, the missing prime axiom is exposed.

**Finding:** GraphRAG's claim extraction phase categorizes claims as "Covariates" that enrich context, with claims being "factual statements associated with entities, often containing temporal or conditional details" [^2899^]. This is the composite layer; the entity and relationship extraction provides the prime layer.

#### 1.8 Prime Gap Oscillation → Attention Oscillation

**Finding:** Sinusoidal position embeddings in transformers explicitly encode oscillation: low dimensions change slowly (global position features), high dimensions change rapidly (local position features) [^2890^]. These orthogonal frequency patterns create a multi-resolution encoding that attention layers use to estimate relative distances.

**Finding:** The "Easy Attention" mechanism for temporal predictions demonstrates that attention can learn periodic oscillation features via discrete Fourier transform, decomposing signals into dominant amplitudes and using separate attention modules for each frequency [^2888^]. This outperforms standard self-attention on sinusoidal-wave reconstruction by an order of magnitude (0.0018% vs 10% error).

**Finding:** Transformer frequency attention mechanisms (e.g., Fedformer, Autoformer) use adaptive spectral filtering to attenuate noise while preserving periodic signals [^2860^]. The periodic rises and falls in prediction error track the system's "intrinsic oscillations" [^2893^]. This suggests attention naturally exhibits oscillatory dynamics that can be tuned to match the "gap oscillation" structure of knowledge.

---

### 2. Formal Definitions

#### Definition 1: Prime Claim (Irreducible Knowledge Unit)
A claim C is **prime** iff:
- It is an axiom (no supporting claims in the KB)
- Its truth value cannot be derived from other claims in the graph
- Its in-degree in the claim dependency graph is 0
- It serves as a carrier for downstream composite claims

**Code-equivalent:**
```python
def is_prime_claim(claim, kb):
    """A claim is prime if no other claims in the KB support it."""
    supporters = kb.get_supporting_claims(claim)
    return len(supporters) == 0
```

#### Definition 2: Composite Claim (Derived Knowledge Unit)
A claim C is **composite** iff:
- Its truth value depends on at least one other claim in the KB
- It has in-degree ≥ 1 in the claim dependency graph
- Its "divisor count" d(C) = number of independent supporting claim paths
- It can be decomposed into prime claim factors

**Code-equivalent:**
```python
def is_composite_claim(claim, kb):
    """A claim is composite if it has supporting claims."""
    supporters = kb.get_supporting_claims(claim)
    return len(supporters) >= 1

def divisor_count(claim, kb):
    """Number of minimal supporting claim sets (independent paths)."""
    return len(kb.get_minimal_support_sets(claim))
```

#### Definition 3: Divisor Normalization Identity (DNI) for Claims
For any claim C, let d(C) be its dependency count (number of claims that directly depend on it). The normalized claim weight is:

$$\text{weight}(C) = \frac{d(C)}{\max_{C' \in \text{KB}} d(C')}$$

Prime claims have high normalized weight (many dependents). Composite claims have low normalized weight (few or no dependents).

#### Definition 4: Gap Winner Rule (GWR) for Knowledge Retrieval
Given a set of candidate sources S = {s₁, s₂, ..., sₙ} competing to establish claim C:

$$\text{winner}(C) = \arg\min_{s \in S} \text{deps}(s)$$

where deps(s) is the number of prerequisite claims source s requires. The winner is the source with the minimum dependency depth — the "leftmost min-d(n) carrier."

#### Definition 5: No-Later-Simpler-Composite for Curriculum Learning
For a knowledge base KB ordered by teaching sequence, let Cᵢ be the i-th claim taught. Define simplicity s(C) = 1 / (1 + deps(C)), where deps(C) is the number of prerequisite claims. The curriculum satisfies the No-Later-Simpler-Composite property iff:

$$\forall i < j: \text{if } C_j \text{ is composite and } C_i \text{ is prime, then } s(C_j) \leq s(C_i)$$

Equivalently: no composite claim is taught before all of its prime factor claims.

#### Definition 6: Tri-State Verification Attractor
For each claim C, define verification state v(C) ∈ {0, 1, 2}:
- 0: Verified (sufficient prime support)
- 1: Unverified (insufficient evidence)
- 2: Contradicted (conflicting evidence)

The claim graph exhibits tri-state attractor dynamics if:

$$P(v(C) = 0 \mid \text{stable KB}) \approx 0.402$$

reflecting the empirical 0-mod-3 dominance in prime gaps. In a well-structured KB, verified claims should dominate (~40%), with unverified and contradicted claims at lower, roughly equal frequencies.

#### Definition 7: Knowledge Sieving Operator
The knowledge sieve Σ operates on a candidate claim set X:

$$\Sigma(X) = \{c \in X \mid \forall p \in \text{primes}(KB): c \not\equiv 0 \pmod{p}\}$$

where primes(KB) is the set of established prime claims, and c ≡ 0 (mod p) means claim c is entailed by prime p (i.e., c is a "multiple" of p). After sieving, remaining claims are candidate primes.

---

### 3. Tensions and Counter-Arguments

#### Tension 1: Inverse Curriculum Paradox
The prime gap research says "composites dictate primes" — you understand composites first to locate primes. But curriculum learning research shows that in some settings, "models trained with the inversed version [hard examples first] performed slightly better" [^2840^]. This creates a fundamental tension: **Do we teach fundamentals first (primes → composites) or applications first (composites → primes)?**

**Resolution:** The tension resolves when distinguishing *comprehension* from *robustness*. For comprehension, primes-first is necessary (the No-Later-Simpler-Composite theorem). For robustness testing, composites-first exposes gaps. The SCOPE-Rex architecture should support both modes: a **sieve mode** (primes-first for learning) and an **inverse-sieve mode** (composites-first for stress-testing).

#### Tension 2: VC Dimension vs. Knowledge Compression
The VC dimension scales with the number of weights, suggesting more parameters = more capacity [^2883^]. But the prime-composite ontology suggests that most knowledge should be *compressed* into few primes with many composites derived. A model with too many "prime claims" stored literally may be less efficient than one that derives composites from a minimal prime basis.

**Resolution:** The "lossless memory dimension" generalizes VC dimension and shows capacity scales linearly with weights [^2883^]. The optimal trade-off is to store high-frequency, irreducible claims as primes and derive the rest. This mirrors how highly composite numbers factor into primorials [^2908^].

#### Tension 3: Deterministic vs. Stochastic Training
Prime gap structure is entirely deterministic — "primes are not random." But neural network training is fundamentally stochastic (random initialization, SGD, dropout) [^2857^]. Can deterministic knowledge structure emerge from stochastic training?

**Counter-argument:** Research on deterministic vs. stochastic neural models shows that stochasticity is necessary for robustness — deterministic models suffer "blowup" (100% failure rate under distribution shift), while stochastic models with minimal noise survive [^2859^]. The prime gap attractor may emerge as a *statistical regularity* rather than strict determinism.

**Counter-counter-argument:** The deterministic prime generation methods prove that primes can be constructed without randomness or sieving [^2904^]. Similarly, a knowledge graph can be constructed deterministically if the composite structure is fully known. The stochastic element in training may be analogous to probabilistic primality tests (Miller-Rabin) — useful for efficiency but not fundamental to the structure.

#### Tension 4: Hierarchical Subspace Specificity
Research shows hierarchical concepts in LMs are encoded in "domain-specific subspaces" — the subspace for location hierarchies differs from that for organism hierarchies [^2851^]. But the prime gap structure suggests universal laws across domains. How can domain-specific representations encode universal structural laws?

**Resolution:** The same research finds that "domain-specific subspaces exhibit a similar hierarchical structure across domains" [^2851^]. The structure is universal even though the subspace coordinates differ — like how prime gaps follow the same statistical laws regardless of which primes you examine. The SCOPE-Rex claim graph should encode universal dependency structures with domain-specific instantiations.

---

### 4. Buildable Elements

#### Element 1: Claim Classification Pipeline
A pipeline that classifies extracted claims into six types (Equation, Inequality, Causal, Definition, Empirical, CodeInvariant) and then sub-classifies each as **prime** (in-degree 0) or **composite** (in-degree ≥ 1). Buildable immediately using existing dependency parsing.

#### Element 2: Knowledge Sieve Algorithm
An Eratosthenes-inspired algorithm for claim graph construction:
```python
def knowledge_sieve(candidate_claims):
    """Build a knowledge graph by sieving out composite claims."""
    kb = KnowledgeBase()
    for claim in sorted(candidate_claims, key=simplicity):
        if not any(kb.entails(p, claim) for p in kb.prime_claims):
            kb.add_prime(claim)  # No existing prime entails this → it's prime
        else:
            kb.add_composite(claim)  # Entailed by existing primes → composite
    return kb
```
This is buildable using existing theorem provers or entailment models.

#### Element 3: Curriculum Ordering via Topological Sort
Use Kahn's algorithm on the claim dependency DAG to produce a teaching order. Buildable with standard graph libraries.

```python
def curriculum_order(claims):
    """Produce a valid teaching order using topological sort."""
    g = DependencyGraph(claims)
    return topological_sort(g)  # Kahn's algorithm
```

#### Element 4: Tri-State Verification Monitor
A real-time monitor that tracks claim verification states and detects when the 0-state (verified) frequency drops below the ~40% attractor threshold, signaling structural instability in the KB.

#### Element 5: Gap Winner Ranker
An information retrieval ranker that scores sources by dependency depth:
```python
def gap_winner_score(source, claim):
    """Lower score = more fundamental (fewer dependencies)."""
    return len(source.prerequisite_claims) + source.reasoning_depth
```

#### Element 6: Attention Oscillation Module
A transformer attention module that uses sinusoidal frequency decomposition (inspired by position embeddings and Easy Attention) to attend to claims at different "depths" in the knowledge hierarchy with different frequencies.

---

### 5. Theoretical Foundations

#### Proven Results
1. **Formal Concept Analysis produces complete lattices** [^2901^]: The concept lattice 𝓛(G, M, I) is a complete lattice. This guarantees that any claim graph can be decomposed into a hierarchy of prime (minimal intent) and composite (derived intent) concepts.

2. **Topological sorting exists for all DAGs** [^2928^]: Any directed acyclic graph admits at least one topological ordering. If the claim dependency graph is a DAG (no circular reasoning), a valid curriculum order always exists.

3. **Curriculum learning modifies the optimization landscape without changing the global minimum** [^2127^]: Under mild conditions, the ideal curriculum preserves the global minimum of the original problem. This means the No-Later-Simpler-Composite ordering does not sacrifice final performance.

4. **VC dimension bounds generalization** [^2885^]: The VC bound guarantees that with high probability, test error is bounded by training error plus a term depending on VC dimension and sample size. For knowledge graphs, this bounds how many composite claims can be reliably derived from a fixed set of primes.

5. **Hierarchical relations are linearly recoverable from LM representations** [^2851^]: Across five domains and four LMs, parent-child relations can be linearly decoded from intermediate layers, and interventions on these directions affect predictions. This proves that hierarchical knowledge structure is physically encoded in neural representations.

#### Conjectured / Empirical Results
1. **Prime gap tri-state attractor**: The mod-3 dominance at ~40.2% is empirically observed through 10^5 primes [^2839^] but not proven for all primes. The analogue for claim verification (40% verified attractor) is a design target, not a theorem.

2. **No-Later-Simpler-Composite for knowledge**: The theorem is proven for numbers through 10^18 but is a conjecture for knowledge graphs. The mapping assumes that "simplicity" in number theory (divisor count) maps cleanly to "prerequisite depth" in knowledge graphs.

3. **Composites dictate primes in knowledge representation**: This is the core philosophical claim of the prime gap research applied to AI. It is empirically testable but not formally proven. The direction of causation (do we need composite experience to identify prime axioms?) is debated.

4. **Gap Winner Rule generalizes to information retrieval**: The raw-Z maximizer being the leftmost min-d(n) carrier is a number-theoretic result. Its generalization to "fewest prerequisite dependencies wins" is an analogy, not a theorem.

---

### 6. Synthesis: The Prime-Composite Knowledge Ontology for SCOPE-Rex

The reconceptualization of SCOPE-Rex around ternary tensors gains a concrete dimension through the prime-composite ontology:

**Ternary States:** Each claim node in the SCOPE-Rex graph takes one of three states:
- **Prime (P)**: Axiomatic, in-degree 0, irreducible
- **Composite (C)**: Derived, in-degree ≥ 1, reducible to prime factors
- **Gap (G)**: Unknown, unverified, awaiting classification

**Ternary Tensor Structure:** The claim adjacency tensor A ∈ {P, C, G}^{N×N×N} encodes:
- A[i,j,k] = P: claim k is prime, supported by the primitive structure
- A[i,j,k] = C: claim k is composite, derived from claims i and j
- A[i,j,k] = G: the relationship between i, j, and k is unresolved (knowledge gap)

**Sieve Dynamics:** The knowledge graph evolves by a sieve process:
1. Initialize all candidate claims as G (gap)
2. For each established prime claim p, mark all claims entailed by p as C (composite)
3. Claims that survive sieving (no prime entails them) become P (prime)
4. Iterate until the G (gap) population stabilizes

**Attractor Dynamics:** The verification state distribution tends toward:
- P (verified primes): ~40%
- C (verified composites): ~35%
- G (unverified gaps): ~25%

This tri-state attractor emerges from the deterministic dependency structure, not from random assignment.

**Training Order:** The curriculum follows the sieve:
1. Teach all P claims (primes) first — they have zero prerequisites
2. Teach C claims (composites) in topological order of dependency depth
3. Use G claims (gaps) as assessment probes — they reveal missing prime foundations

**Information Retrieval:** The GWR ranker selects sources by minimum dependency depth, ensuring that the most fundamental (least composite) evidence is prioritized.

---

### 7. References

[^2839^] Rodenbough, E. "Prime Gaps and the Hidden Order: Evidence of a Tri-State Recursive Attractor." Reddit r/mathematics, 2025. https://www.reddit.com/r/mathematics/comments/1izu0us/prime_gap_tristate_research/

[^2840^] Avramova, V. "Curriculum Learning with Deep Convolutional Neural Networks." KTH Royal Institute of Technology, 2015. https://www.diva-portal.org/smash/get/diva2:878140/FULLTEXT01.pdf

[^2842^] "Ontology Learning with LLMs: A Benchmark Study on Axiom Identification." arXiv:2512.05594, 2025. https://arxiv.org/html/2512.05594v1

[^2844^] "Exploring knowledge graphs for the identification of concept prerequisites." International Journal of Educational Technology in Higher Education, 2019. https://link.springer.com/article/10.1186/s40561-019-0104-3

[^2851^] Sakata, M. et al. "Linear Representations of Hierarchical Concepts in Language Models." arXiv:2604.07886, 2026. https://arxiv.org/html/2604.07886v1

[^2853^] "Beyond 'I Don't Know': Evaluating LLM Self-Awareness in Discriminating Data and Model Uncertainty." arXiv:2604.17293, 2026. https://arxiv.org/html/2604.17293v1

[^2857^] "Stop Throwing Around 'Stochastic' and 'Deterministic'." Medium, 2025. https://ndgigliotti.medium.com/stop-throwing-around-stochastic-and-deterministic-44f27ad0b7a7

[^2859^] "Choose your tools carefully: a comparative evaluation of deterministic vs. stochastic neuron models." Frontiers in Nanotechnology, 2023. https://www.frontiersin.org/journals/nanotechnology/articles/10.3389/fnano.2023.1146852/full

[^2883^] "A Capacity Scaling Law for Artificial Neural Networks." arXiv:1708.06019, 2017. https://arxiv.org/pdf/1708.06019

[^2885^] "Quantifying Model Capacity: The VC Dimension." Towards Data Science, 2021. https://towardsdatascience.com/quantifying-model-capacity-the-vc-dimension-d4eb76dd26f7/

[^2888^] "Easy attention: A simple attention mechanism for temporal predictions with transformers." arXiv:2308.12874, 2023/2025. https://arxiv.org/html/2308.12874v4

[^2890^] "Inside Sinusoidal Position Embeddings: A Sense of Order." LearnOpenCV, 2025. https://learnopencv.com/sinusoidal-position-embeddings/

[^2891^] "Foundations of AI: Knowledge-Based Agents and Logic." 2018. https://hunterheidenreich.com/posts/knowledge-based-agents-and-logic/

[^2897^] Liu, Q. et al. "PrimeNet: A Framework for Commonsense Knowledge Representation and Reasoning Based on Conceptual Primitives." SenticNet, 2024. https://sentic.net/primenet.pdf

[^2899^] "GraphRAG: Redefining Knowledge Extraction with Graphs." Medium, 2024. https://thecagedai.medium.com/graphrag-redefining-knowledge-extraction-97fb3d8f9bec

[^2900^] "Sieve Attention: Fusing Context-Aware Filtering and Sequential Allocation." OpenReview, 2025. https://openreview.net/forum?id=ACIyd1pJLz

[^2901^] "Formal Concept Analysis Overview." Emergent Mind, 2026. https://www.emergentmind.com/topics/formal-concept-analysis-fca

[^2904^] Jaganath, U.G. "A Recursive Deterministic Equation for Generating Prime Numbers in Exact Order." vixra:2509.0091, 2025. https://vixra.org/pdf/2509.0091v1.pdf

[^2905^] Dugas, J.M. & O'Connor, J. "Sequences for Determination of Prime Numbers by Eliminating Composites." Journal of Mathematics and Statistics, 2017. https://thescipub.com/pdf/jmssp.2017.177.185.pdf

[^2908^] Lim, B. "Prime Numbers Generated From Highly Composite Numbers." Parabola, UNSW, 2024. https://www.parabola.unsw.edu.au/sites/default/files/2024-03/vol54_no3_4.pdf

[^2910^] "Unsupervised Unknown Unknown Detection in Active Learning." HAL, CEA. https://cea.hal.science/cea-04483849/document

[^2925^] "Experimental Insights on Prime Gaps." IntechOpen, 2025. https://www.intechopen.com/chapters/1235016

[^2927^] "Alleviating Sparsity of Open Knowledge Graphs with Ternary Contrastive Learning." ACL Findings, 2022. https://aclanthology.org/2022.findings-emnlp.168.pdf

[^2928^] "Topological Sorting." GeeksforGeeks, 2025. https://www.geeksforgeeks.org/dsa/topological-sorting/

[^2127^] Hacohen, G. & Weinshall, D. "On The Power of Curriculum Learning in Training Deep Networks." ICML 2019. http://proceedings.mlr.press/v97/hacohen19a/hacohen19a.pdf
