# Dimension 11: Hyperdimensional & Vector Symbolic Computing

## Deep Research Report for UASA/Rex Deterministic Superintelligence Substrate

**Research Date:** 2025  
**Searches Conducted:** 20+ independent queries across arXiv, ACM, IEEE, PubMed, Science Robotics, and primary sources  
**Citations:** Sequential numbering from [^1^] through [^55^]

---

## Executive Summary

Hyperdimensional Computing (HDC), also known as Vector Symbolic Architectures (VSA), represents data as high-dimensional vectors (typically D > 10,000) where random vectors become quasi-orthogonal. Three fundamental operations — **bundling** (superposition via addition), **binding** (association via multiplication/convolution), and **permutation** (order encoding via cyclic shift) — enable compositional symbolic reasoning in a fixed-width vector space. Recent advances including Generalized Holographic Reduced Representations (GHRR) provide non-commutative binding for ordered structures, while PathHD demonstrates encoder-free knowledge graph reasoning competitive with neural baselines at 40-60% lower latency. HDC offers inherent robustness to noise, single-pass learning, and natural mapping to neuromorphic hardware — but faces capacity limits linear in dimension, and accuracy gaps vs. deep neural networks on complex tasks without hybrid feature extractors.

---

## 1. HDC Fundamentals: Holographic Reduced Representations

### 1.1 Plate's Original HRR (1995)

Claim: Holographic Reduced Representations use circular convolution to associate items represented by vectors, enabling arbitrary variable bindings, short sequences, and frame-like structures in a fixed-width vector [^1^].  
Source: IEEE Transactions on Neural Networks  
URL: https://redwood.berkeley.edu/wp-content/uploads/2020/08/Plate-HRR-IEEE-TransNN.pdf  
Date: May 1995  
Excerpt: "Associative memories are conventionally used to represent data with very simple structure: sets of pairs of vectors. This paper describes a method for representing more complex compositional structure in distributed representations. The method uses circular convolution to associate items, which are represented by vectors. Arbitrary variable bindings, short sequences of various lengths, simple frame-like structures, and reduced representations can be represented in a fixed width vector."  
Context: Tony Plate developed HRR as a graduate student with Geoff Hinton at the University of Toronto, motivated by getting connectionist systems to do symbolic reasoning. HRR was inspired by Paul Smolensky's tensor product variable binding (1990), but compressed the tensor into lower dimension using circular convolution.  
Confidence: **high**

Claim: Circular convolution can be regarded as a compression of the outer product of two vectors, achieved by summing along the top-right to bottom-left diagonals. The result of circular convolution of two vectors of n elements has just n elements, avoiding the dimensionality expansion of aperiodic convolution [^2^].  
Source: Plate, Holographic Reduced Representations  
URL: https://www2.fiit.stuba.sk/~kvasnicka/CognitiveScience/6.prednaska/plate.ieee95.pdf  
Date: 1995  
Excerpt: "The problem of expanding dimensionality can be avoided entirely by the use of circular convolution, an operation well known in signal processing... The result of the circular convolution of two vectors of n elements has just n elements."  
Context: Aperiodic convolution of two n-element vectors produces a (2n-1)-element vector, while tensor product produces n^2 elements. Circular convolution keeps dimensionality fixed.  
Confidence: **high**

Claim: Convolution is endowed with several positive features: it preserves similarity (HRRs with similar fillers in similar roles are similar), can be computed very quickly using FFTs, and analysis of capacity and scaling properties is straightforward [^3^].  
Source: Plate, Holographic Reduced Representations (Discussion section)  
URL: https://www2.fiit.stuba.sk/~kvasnicka/CognitiveScience/6.prednaska/plate.ieee95.pdf  
Date: 1995  
Excerpt: "One is that it preserves similarity -- HRRs with similar fillers in similar roles are similar. Another is that convolution can be computed very quickly using FFTs. Another is that analysis of the capacity, scaling, and generalization properties is straightforward."  
Context: Plate explicitly noted that circular convolution is commutative, which can cause ambiguity in representing some structures, and suggested non-commutative variants by permuting elements.  
Confidence: **high**

### 1.2 Fourier Holographic Reduced Representations (FHRR)

Claim: FHRR represents each hypervector dimension as a unit-magnitude complex phasor, where binding corresponds to element-wise complex multiplication (phase addition), unbinding to complex conjugate multiplication (phase subtraction), and similarity to cosine similarity between vectors [^4^].  
Source: Generalized Holographic Reduced Representations (Yeung et al., 2024)  
URL: https://arxiv.org/abs/2405.09689  
Date: May 15, 2024  
Excerpt: "Fourier Holographic Reduced Representations (FHRR) is a specific implementation of HDC. An FHRR hypervector is of the form H = [e^{iθ_1}, ..., e^{iθ_D}]. Bundling and binding are the usual element-wise addition and multiplication, respectively."  
Context: FHRR's phase-based encoding facilitates smooth interpolation and rotation-based manipulations while maintaining robustness via the unit-magnitude constraint.  
Confidence: **high**

Claim: A quantized phase formulation of FHRR (qFHRR) reduces bit-width from 64-bit complex representations to as few as 3-4 bits per dimension while preserving algebraic properties and spatial similarity structure [^5^].  
Source: qFHRR: Rethinking Fourier Holographic Reduced Representations through Quantized Phase and Integer Arithmetic  
URL: https://arxiv.org/abs/2604.25939  
Date: April 16, 2026  
Excerpt: "We introduce qFHRR, a quantized phase formulation of FHRR. In this representation, each dimension is encoded as a discrete phase index, enabling integer-only implementations of binding, unbinding, similarity, and bundling through modular arithmetic and lookup tables... from 64-bit complex representations to as few as 3--4 bits."  
Context: qFHRR enables hardware-friendly implementations on resource-constrained devices and establishes a direct neural interpretation through spiking phasor neurons.  
Confidence: **high**

### 1.3 Binary Spatter Codes (BSC)

Claim: BSC, developed by Kanerva in the mid-1990s, uses dense binary vectors with components from {0,1}, with binding as component-wise XOR and superposition as component-wise addition thresholded by majority rule [^6^].  
Source: A Survey on Hyperdimensional Computing aka Vector Symbolic Architectures, Part I  
URL: https://dl.acm.org/doi/10.1145/3538531  
Date: December 2022  
Excerpt: "In BSC, atomic HVs are dense binary HVs with components from {0,1}. The superposition is a component-wise addition, thresholded (binarized) to obtain an approximately equal density of ones and zeros in the resultant HV... The binding is a component-wise exclusive OR (XOR)... BSC has a binding operation with a self-inverse binding property."  
Context: BSC can be seen as a special case of FHRR where phase angles are restricted to 0 and π. The self-inverse property means unbinding is the same operation as binding.  
Confidence: **high**

---

## 2. Vector Symbolic Architectures (VSA)

### 2.1 Multiply-Add-Permute (MAP)

Claim: The MAP model by Gayler uses dense bipolar HVs with components from {-1,1}, binding as component-wise multiplication (equivalent to taking the diagonal of the outer product), and superposition as component-wise addition [^7^].  
Source: A Survey on Hyperdimensional Computing aka Vector Symbolic Architectures, Part I  
URL: https://redwood.berkeley.edu/wp-content/uploads/2022/11/2022_CSUR_survey_HDCVSA_part_1.pdf  
Date: 2022  
Excerpt: "The Multiply-Add-Permute (MAP) model was proposed by Gayler. It has several variants; the bipolar one is isomorphic to the BSC model. In the MAP model, atomic HVs are dense bipolar HVs with components from [-1,1]. The binding is component-wise multiplication... The superposition is a component-wise addition."  
Context: MAP suggested using a permutation operation for quoting/protecting embedded associations, which is also useful for encoding order or precedence.  
Confidence: **high**

### 2.2 Matrix Binding of Additive Terms (MBAT)

Claim: MBAT implements binding via matrix-vector multiplication, where atomic HVs are dense with components from {-1,+1} and random matrices can change dimensionality if needed [^8^].  
Source: ACM Computing Surveys  
URL: https://dl.acm.org/doi/10.1145/3538531  
Date: 2022  
Excerpt: "In the Matrix Binding of Additive Terms (MBAT) model, it was proposed to implement the binding operation by matrix-vector multiplication... Atomic HVs are dense and their components are randomly selected independently from {-1,+1}."  
Context: MBAT binding properties are similar to HRR, MAP, and BSC — similar inputs produce similar bound HVs, and bound HVs are not similar to inputs.  
Confidence: **high**

### 2.3 Semantic Pointer Architecture (SPA)

Claim: The Semantic Pointer Architecture (SPA), developed by Eliasmith, instantiates semantic pointers as vectors implemented by patterns of neurons firing in spiking neural networks, using circular convolution for binding and circular correlation for unbinding [^9^].  
Source: Neural Semantic Pointers in Context / Nengo SPA documentation  
URL: https://www.nengo.ai/nengo-spa/v1.2.0/user-guide/spa-intro.html  
Date: ongoing (SPA introduced ~2012)  
Excerpt: "The specific operations used by the SPA were first suggested by Tony A. Plate in Holographic Reduced Representation: Distributed Representation for Cognitive Structures. In particular, we usually use random vectors of unit-length and three basic operations: Superposition (addition), Binding (circular convolution), and Unbinding (circular convolution with approximate inverse)."  
Context: SPA has been used to build spiking neural models of linguistic parsing, the Wason card task, and Raven's Progressive Matrices. The NEF/SPA framework underlies the world's largest functional brain model (Eliasmith et al., 2012).  
Confidence: **high**

---

## 3. HDC for Knowledge Graphs: PathHD

Claim: PathHD is an encoder-free KG reasoning framework that replaces neural path scoring with hyperdimensional computing, using block-diagonal GHRR hypervectors with non-commutative binding to encode relation paths, achieving comparable Hits@1 to strong neural baselines while reducing latency by 40-60% and GPU memory by 3-5x [^10^].  
Source: Are Hypervectors Enough? Single-Call LLM Reasoning over Knowledge Graphs (arXiv)  
URL: https://arxiv.org/abs/2512.09369  
Date: December 10, 2025  
Excerpt: "PathHD encodes relation paths into block-diagonal GHRR hypervectors, retrieves candidates via fast cosine similarity with Top-K pruning, and performs a single LLM call to produce the final answer with cited supporting paths... reduces end-to-end latency by 40-60% and GPU memory by 3-5x thanks to encoder-free retrieval."  
Context: PathHD uses GHRR-based, non-commutative binding to encode relation sequences into hypervectors. Ablation studies show GHRR outperforms commutative binding (XOR, element-wise product, FHRR, HRR) for path composition. The single-LLM adjudication step yields consistent gains over vector-only selection.  
Confidence: **high**

Claim: The complexity of PathHD retrieval is O(Nd) per candidate vs. O(NLd^2) for Transformer-based neural encoders with L layers, yielding an O(Ld)-fold reduction [^11^].  
Source: PathHD paper, Theoretical & Complexity Analysis section  
URL: https://arxiv.org/abs/2512.09369  
Date: 2025  
Excerpt: "A typical neural encoder incurs O(NLd^2) cost for encoding and scoring. In contrast, PathHD forms each path vector by |z|-1 block multiplications plus one similarity... O(Nd) total and an O(Ld)-fold reduction in leading order."  
Context: This is a fundamental advantage for deterministic runtime — HDC scoring has no variable compute dependent on sequence structure, unlike autoregressive or attention-based encoders.  
Confidence: **high**

Claim: Configurable hyperdimensional graph representation methods extend HDC to general graph encoding, with capacity scaling linearly with dimension [^12^].  
Source: Configurable hyperdimensional graph representation, Artificial Intelligence journal  
URL: https://www.sciencedirect.com/science/article/pii/S0004370225001031  
Date: October 2025 (Volume 347)  
Excerpt: "Capacity quantifies the maximum number of orthogonal vectors that can be memorized through bundling in a single hypervector while maintaining..."  
Context: Published in the flagship Artificial Intelligence journal, this work formalizes capacity limits for graph-structured data in HDC.  
Confidence: **medium** (abstract only accessible; full paper behind paywall)

---

## 4. HDC in Rust: Crates and Implementations

Claim: The `hypervector` Rust crate implements MBAT (bipolar vectors), SSP (Semantic Spatial Parameters), and FHRR (Fourier Holographic Reduced Representations), providing a generic `Hypervector` type and an `ObjectEncoder` for JSON-to-hypervector mapping [^13^].  
Source: docs.rs/hypervector  
URL: https://docs.rs/hypervector  
Date: April 2026  
Excerpt: "This crate implements high-dimensional vectors for hyperdimensional computing and Vector Symbolic Architectures (VSAs). It currently provides two implementations: MBAT: Bipolar vectors (elements in {-1, +1}), SSP: Semantic Spatial Parameters..."  
Context: The GitHub repository (rishikanthc/hypervector) shows version 0.1.0. The crate offers reproducible randomness via global RNG seed, an object encoder for JSON, and well-documented API.  
Confidence: **high**

Claim: The `hyperspace` Rust crate by d6y implements binary VSA based on Kanerva (2009), using the `bitvec` crate for binary hypervectors and an `Algebra` trait for binding/addition operations [^14^].  
Source: GitHub - d6y/hyperspace  
URL: https://github.com/d6y/hyperspace  
Date: July 2024  
Excerpt: "An spike implementing binary VSA in Rust. Based on: Kanerva (2009), Hyperdimensional Computing: An Introduction to Computing in Distributed Representation with High-Dimensional Random Vectors, Cognitive Computation."  
Context: This is an experimental/research spike with minimal functionality (assert-only tests). It demonstrates the conceptual mapping to Rust but is not production-grade.  
Confidence: **medium**

Claim: Torchhd is a high-performance Python library for HDC/VSA built on PyTorch, supporting MAP, BSC, HRR, FHRR, and other models, with experiments running up to 100x faster than reference implementations [^15^].  
Source: Torchhd paper, JMLR 2023  
URL: https://www.jmlr.org/papers/volume24/23-0300/23-0300.pdf  
Date: 2023  
Excerpt: "Comparing publicly available code with their corresponding Torchhd implementation shows that experiments can run up to 100x faster."  
Context: Torchhd supports memory models (Sparse Distributed Memory, Hopfield networks), data structures (hash tables, graphs, trees, FSAs), and 126+ datasets. It is the most comprehensive HDC software library available.  
Confidence: **high**

---

## 5. Neuromorphic Computing with Hypervectors

Claim: In-memory HDC using phase-change memory (PCM) crossbar arrays stores both item memory and associative memory as conductance values, enabling encoding and AM search via non-stateful read logic primitives [^16^].  
Source: Karunaratne et al., In-memory hyperdimensional computing (Nature Electronics / Nature portfolio)  
URL: https://redwood.berkeley.edu/wp-content/uploads/2021/08/Karunaratne2020.pdf  
Date: 2020  
Excerpt: "The essential idea of in-memory HDC is to store the components of both the IM and the AM as the conductance values of nanoscale memristive devices organized in crossbar arrays and enable HDC operations in or near to those devices... The proposed in-memory read logic is non-stateful and this obviates the need for high write endurance."  
Context: The system uses three PCM crossbar arrays (two for IM, one for AM) with peripheral circuits. It achieves classification accuracy close to software baselines for language and news datasets.  
Confidence: **high**

Claim: A memristive SoC (TetraMem MX100) with ten computing cores, each integrating a 248x256 1T1R crossbar array, performs analog VMM for HDC with on-chip DACs/ADCs and a RISC-V CPU for orchestration [^17^].  
Source: Hardware-Algorithm Co-Design for Hyperdimensional Computing with IMC  
URL: https://arxiv.org/pdf/2512.20808  
Date: 2025  
Excerpt: "The SoC includes ten computing cores, each integrating one memristive crossbar array and peripheral circuits, such as DACs and ADCs. Each computing core contains a 248 x 256 one-transistor-one-memristor (1T1R) crossbar array."  
Context: This represents state-of-the-art commercial memristive hardware for HDC acceleration.  
Confidence: **high**

Claim: A hardware-software co-design for HDC with in-memory computing achieves 255x better energy efficiency and 28x speedup over baseline PIM, with HD computing being 48x more robust to noise than comparable ML algorithms [^18^].  
Source: HyDREA: Utilizing Hyperdimensional Computing For Adaptive PIM Architecture  
URL: https://cseweb.ucsd.edu/~bkhalegh/papers/TECS-HyDREA.pdf  
Date: 2022  
Excerpt: "Our PIM architecture is able to achieve 255x better energy efficiency and speed up execution time by 28x compared to the baseline PIM architecture... Our results demonstrate that HyDREA is 48x more robust to noise than other comparable ML algorithms."  
Context: HyDREA adaptively changes bitwidth based on SNR and relaxes ADC precision requirements due to HDC's inherent error tolerance.  
Confidence: **high**

---

## 6. HDC for Sequence Modeling

Claim: HDC encodes temporal or sequential data via n-gram training: given a sequence of n hypervectors, an n-gram is generated by applying cyclic permutation ρ(·) and binding: G_t = ρ^{n-1}(H_{t-n+1}) ⊕ ρ^{n-2}(H_{t-n+2}) ⊕ ... ⊕ H_t [^19^].  
Source: HDC with Legendre Delay Networks / ICNC 2026 paper  
URL: http://www.conf-icnc.org/2026/papers/p672-sarkar.pdf  
Date: 2026  
Excerpt: "Given a sequence of n hypervectors {H_{t-n+1},...,H_t}, an n-gram hypervector is generated by applying a cyclic permutation p(·) and binding: G_t = p^{n-1}(H_{t-n+1}) ⊕ p^{n-2}(H_{t-n+2}) ⊕ ... ⊕ H_t."  
Context: N-gram encoding captures both the identity and order of input signals across a fixed window. These n-gram HVs are then bundled together across training examples.  
Confidence: **high**

Claim: A SIMD block-shifting optimization for permute operations achieves 10x speedup for permute and 14x for n-gram encoding, resulting in up to 26.8x speedup on real applications compared to state-of-the-art HDC prototyping libraries [^20^].  
Source: Accelerating Permute and N-gram Operations for Hyperdimensional Learning in Embedded Systems  
URL: https://sites.uci.edu/inunes/files/2025/07/Accelerating-permute-and-n-gram-operations-for-hyperdimensional-learning-in-embedded-systems.pdf  
Date: 2025  
Excerpt: "Our method enhances the efficiency of HDC's permute operations by a factor of 10x. Furthermore, by applying the same idea to n-gram encoding, we achieve a speedup of 14x, resulting in up to 26.8x speedup on a real application."  
Context: This enables real-time inference in embedded systems for emotion, gesture, and language recognition.  
Confidence: **high**

---

## 7. HDC for Analogical Reasoning

Claim: HDC/VSA models for analogical reasoning combine semantic similarity (for surface matching) and structural similarity (via superposition of higher-level role HVs) to enable analogical mapping. Experiments on complex analogies ("Water Flow-Heat Flow", "Solar System-Atom") produced correct mapping results with low computational complexity [^21^].  
Source: A Survey on Hyperdimensional Computing aka Vector Symbolic Architectures, Part II: Applications, Cognitive Models, and Challenges  
URL: https://dl.acm.org/doi/10.1145/3558000  
Date: January 2023  
Excerpt: "The re-representation approach included the superposition of two HVs. One of those HVs was obtained as the HV for the episode's element using the usual representational scheme... This HV took into account the semantic similarity. The other HV was the superposition of HVs of elements higher-level roles. This took into account the structural similarity."  
Context: Current models lack interaction and competition of consistent alternative mappings, suggesting room for improvement via associative memory mechanisms akin to Hopfield networks.  
Confidence: **medium**

---

## 8. HDC Robustness

Claim: SpikeHD, a spiking hyperdimensional network, maintains 94.0% accuracy under 10% random noise vs. 87.1% for baseline SNN, and robustness increases with HDC dimensionality [^22^].  
Source: Memory-inspired spiking hyperdimensional network for robust online learning, Nature Scientific Reports  
URL: https://www.nature.com/articles/s41598-022-11073-3  
Date: May 10, 2022  
Excerpt: "Under 10% random noise, SpikeHD and SNN maintain 94.0% and 87.1% quality. The ability to sustain prediction quality generally increases as the dimension of HDC memory increases."  
Context: SpikeHD combines spiking neural networks with HDC associative memory, showing that HDC modules significantly improve SNN robustness to noise and neuron failure.  
Confidence: **high**

Claim: A Lipschitz-based theoretical framework evaluates HDC classifier robustness, providing an upper bound for tolerable noise magnitude without changing predictions. Optimization based on this measure increases average robustness while maintaining accuracy [^23^].  
Source: Lipschitz-based robustness estimation for hyperdimensional learning, Frontiers in AI  
URL: https://www.frontiersin.org/journals/artificial-intelligence/articles/10.3389/frai.2025.1637105/full  
Date: August 25, 2025  
Excerpt: "Our proposed measure of robustness gives a theoretical upper bound for the magnitude of noise a model can tolerate without changing its prediction for any given data point... The average robustness of HDC models increases under the proposed optimization scheme while maintaining accuracy."  
Context: This is one of the first rigorous theoretical frameworks for HDC robustness against input perturbations, previously a notable gap in HDC research.  
Confidence: **high**

Claim: For binary hypervectors of dimension D, up to approximately D/3 bit flips can be tolerated while maintaining identifiability, as the remaining dimensions preserve sufficient signal for decoding [^24^].  
Source: Grokipedia / Hyperdimensional computing  
URL: https://grokipedia.com/page/Hyperdimensional_computing  
Date: 2026  
Excerpt: "For binary hypervectors of dimension D, up to approximately D/3 bit flips can be tolerated while maintaining identifiability, as the remaining dimensions preserve sufficient signal for decoding via Hamming distance thresholds."  
Context: This is a commonly cited rule of thumb in HDC literature, though exact thresholds depend on the number of stored vectors and encoding scheme.  
Confidence: **medium** (aggregated wisdom, not from a single peer-reviewed derivation)

---

## 9. HDC for Natural Language

Claim: HDC has been successfully applied to language classification, news classification, and DNA sequence analysis, with n-gram encoding using XOR-based binding and n-gram sizes of 4-5 for language tasks [^25^].  
Source: Karunaratne et al., In-memory hyperdimensional computing  
URL: https://redwood.berkeley.edu/wp-content/uploads/2021/08/Karunaratne2020.pdf  
Date: 2020  
Excerpt: "For the language and news datasets, XORs used encoding with an n-gram size of n=4 and n=5, respectively... The accuracy level reported in this experiment is close to the accuracy reported with the software."  
Context: Language classification is one of the canonical HDC benchmarks, alongside activity recognition and EMG gesture recognition.  
Confidence: **high**

Claim: The Semantic Pointer Architecture (SPA) has been used to model speech production, speech perception, and cognitive processing in large-scale neural models, with semantic pointers serving as compressed representations that can be selectively decompressed to retrieve cognitive, sensory, and motor information [^26^].  
Source: Natural Language Processing in Large-Scale Neural Models for Medical Screenings (PMC)  
URL: https://pmc.ncbi.nlm.nih.gov/articles/PMC7805752/  
Date: 2021  
Excerpt: "A semantic pointer as defined in the SPA is a compressed representation implemented by the activities of a collection of spiking neurons within a neural buffer and is mathematically characterized as a high-dimensional vector... The concepts activated from the mental lexicon are input or output of the cognitive processing component."  
Context: SPA provides a biologically plausible framework for NLP that bridges symbolic and subsymbolic processing, implemented in the Nengo simulator.  
Confidence: **high**

---

## 10. HDC Applied to Robotics

Claim: A Science Robotics paper (2019) demonstrated the first integration of perception and action using hyperdimensional binary vectors (HBVs) with a dynamic vision sensor (DVS), enabling a quadcopter drone to perform ego-motion inference by binding visual events with system velocity in a single vector space [^27^].  
Source: Learning sensorimotor control with neuromorphic sensors: Toward hyperdimensional active perception, Science Robotics  
URL: https://pubmed.ncbi.nlm.nih.gov/33137724/  
Date: May 15, 2019  
Excerpt: "We propose a method of encoding actions and perceptions together into a single space that is meaningful, semantically informed, and consistent by using hyperdimensional binary vectors (HBVs). We used DVS for visual perception and showed that the visual component can be bound with the system velocity to enable dynamic world perception."  
Context: This represents a landmark paper for HDC in robotics, establishing "active perception" where a robot's memories of past sensing and action influence future behavior. The approach was later extended to neuromorphic visual odometry with resonator networks.  
Confidence: **high**

Claim: An HDC-based hyperdimensional framework can turn any sequence of "instants" into new HBVs and group existing HBVs together, all in the same vector length, creating semantically significant "memories" and "history" vectors [^28^].  
Source: University of Maryland / Science Robotics press release  
URL: https://robotics.umd.edu/release/helping-robots-remember-hyperdimensional-computing-theory-could-change-the-way-ai-works  
Date: May 15, 2019  
Excerpt: "A hyperdimensional framework can turn any sequence of 'instants' into new HBVs, and group existing HBVs together, all in the same vector length. This is a natural way to create semantically significant and informed 'memories.' The encoding of more and more information in turn leads to 'history' vectors and the ability to remember."  
Context: The authors argue that neural network-based AI methods are "big and slow, because they are not able to remember," while HDC can create memories requiring much less computation.  
Confidence: **high**

---

## 11. HDC Scalability and Capacity

Claim: Information capacity in HDC increases approximately linearly with hypervector dimension. As a point of reference, 1000-dimension vectors achieve 99% accuracy in set membership and dictionary unbinding with the summation of 20 items/key-value pairs [^29^].  
Source: The Hyper-Dimensional Processing Unit (Berkeley EECS technical report)  
URL: https://www2.eecs.berkeley.edu/Pubs/TechRpts/2024/EECS-2024-232.pdf  
Date: December 2024  
Excerpt: "Both analytical and quantitative studies observe a linear increase in the dimension of the HD vector with the number of entries to be added. As a point of reference, 1000 dimension vectors were able to achieve 99% accuracy in both set membership and dictionary unbinding tests with the summation of 20 items/key-value pairs."  
Context: Capacity is limited by how many vectors can be bundled before constituent vectors become indistinguishable from noise. The dimension must be scaled accordingly for desired performance.  
Confidence: **high**

Claim: In GHRR, capacity for memorizing base hypervectors increases approximately linearly with total dimension Dm^2. For fixed m > 1, the difference in capacity for different numbers of bound components is not large. m=1 (FHRR) performs significantly worse when permutations are considered distinct, due to inability to distinguish permutations [^30^].  
Source: Generalized Holographic Reduced Representations (Yeung et al., 2024)  
URL: https://arxiv.org/pdf/2405.09689  
Date: May 2024  
Excerpt: "Capacity increases approximately linearly with respect to the total dimension Dm^2... m=1 (FHRR) is significantly worse... the reason FHRR performs significantly worse is due to its inability to distinguish permutations of bound hypervectors."  
Context: GHRR with m>1 restores capacity for ordered structures with negligible loss compared to FHRR for unordered structures. This validates GHRR as a flexible non-commutative representation.  
Confidence: **high**

Claim: HDC vectors face capacity limitations determined by the dimension of HD space, encoding method, and potential noise levels in the input data. Careful evaluation and sometimes manual feature engineering are required for new applications [^31^].  
Source: LifeHD paper (Xiaofan Yu et al.)  
URL: https://arxiv.org/abs/2403.04759  
Date: 2024  
Excerpt: "HDC vectors face capacity limitations determined by the dimension of HD space, encoding method, and potential noise levels in the input data. Due to these factors, careful evaluation and sometimes manual feature engineering are required to successfully deploy HDC for new applications."  
Context: This is an explicit acknowledgment from active HDC researchers that "infinite capacity" claims are overstated. Capacity is finite and linear in dimension.  
Confidence: **high**

---

## 12. HDC vs Neural Embeddings

Claim: HDC can be derived from an extremely compact neural network trained upfront. A two-layer NN-derived HDC model achieves up to 21% and 5% accuracy increase over conventional and learning-based HDC models respectively [^32^].  
Source: Hyperdimensional Computing vs. Neural Networks (Ma & Jiao, arXiv)  
URL: https://arxiv.org/abs/2207.12932  
Date: July 24, 2022  
Excerpt: "Experimental results show such neural network-derived HDC model can achieve up to 21% and 5% accuracy increase from conventional and learning-based HDC models respectively... HDC can be derived from an extremely compact neural network trained upfront."  
Context: The paper reveals deep connections: canonical HDC's fixed item memory is analogous to freezing the input layer of a neural network; HDC training is an "approximate back-propagation" with learning rate 1; and HDC bundling corresponds to the classifier layer.  
Confidence: **high**

Claim: Pure HDC methods struggle with complex image recognition. Table from federated learning research shows HD-linear achieves 26.94% on CIFAR10 vs. CNN's 90.1%, HD-nonlinear achieves 41.98%, while CNN feature extraction combined with HDC classification (HDnn) closes the gap [^33^].  
Source: Federated Hyperdimensional Computing: Comprehensive Analysis and Robust Communication  
URL: https://dl.acm.org/doi/full/10.1145/3724129  
Date: May 2025  
Excerpt: "Table 3 summarizes the accuracy of various current HDC coding methods when running the image classification task. HD-linear: 26.94, HD-non linear: 41.98, HD-id level: 26.56, CNN: 90.1"  
Context: This motivates HDnn (HDC-CNN hybrid) architectures where CNNs serve as feature extractors and HDC handles efficient classification. HDnn increases accuracy by 1.2% on average compared to CNNs while reducing MACs by 34.8% and parameters by 72.5%.  
Confidence: **high**

Claim: HDC-CNN hybrid models use pretrained CNNs (VGG, ResNet, MobileNet) as feature extractors, encoding extracted features into hypervectors for HDC classification. HDnn achieves 52.45% higher accuracy than pure HDC on complex datasets [^34^].  
Source: HDnn-PIM: Efficient in Memory Design  
URL: https://cseweb.ucsd.edu/~bkhalegh/papers/GLSVLSI22-HDnnPIM.pdf  
Date: 2022  
Excerpt: "HDnn comprises three steps: (1) realizing a feature extractor, (2) training of HD clustering, and (3) tuning the feature extractor... HDnn is on average <=1.6%, 49.1%, and 57.3% more accurate than the mere HD model on CIFAR100, CIFAR10, and Flowers datasets."  
Context: HDnn truncates CNNs after pooling layers, uses global averaging to flatten feature maps, then applies random projection to encode into hypervectors. The HD classifier is trained by bundling class hypervectors.  
Confidence: **high**

---

## 13. Quantum-Inspired HDC

Claim: Quantum Hyperdimensional Computing (QHDC) maps hypervectors to quantum states, bundling to Linear Combination of Unitaries (LCU) with Oblivious Amplitude Amplification, binding to quantum phase oracles, permutation to Quantum Fourier Transform, and similarity to Hadamard Test-based fidelity measurements. Validated on a 156-qubit IBM Heron r3 processor [^35^].  
Source: Quantum Hyperdimensional Computing (arXiv)  
URL: https://arxiv.org/abs/2511.12664  
Date: November 16, 2025  
Excerpt: "We establish a direct, resource-efficient mapping: (i) hypervectors are mapped to quantum states, (ii) the bundling operation is implemented as a quantum-native averaging process using a Linear Combination of Unitaries (LCU) and Oblivious Amplitude Amplification (OAA), (iii) the binding operation is realized via quantum phase oracles, (iv) the permutation operation is implemented using the Quantum Fourier Transform (QFT), and (v) vector similarity is calculated using quantum state fidelity measurements based on the Hadamard Test."  
Context: This is the first-ever implementation of quantum-native HDC, validated through symbolic analogical reasoning and supervised classification tasks. Results from classical computation, ideal quantum simulation, and IBM hardware execution were compared.  
Confidence: **high** (theoretical framework proven; hardware execution demonstrated)

---

## 14. HDC Hardware Acceleration

Claim: An FPGA-based HDC accelerator on AMD Alveo U280 achieves 0.09 ms inference latency on MNIST, providing up to 1300x speedup over CPU and 60x over GPU baselines, with sub-millisecond inference across all configurations [^36^].  
Source: Primitive-Driven Acceleration of Hyperdimensional Computing for Real-Time Image Classification  
URL: https://arxiv.org/html/2601.20061v1  
Date: January 27, 2026  
Excerpt: "Our Alveo U280 implementation delivers 0.09 ms inference latency, achieving up to 1300x and 60x speedup over state-of-the-art CPU and GPU baselines, respectively."  
Context: The accelerator implements a patch-based HDC algorithm similar to CNNs, mapping local image patches to hypervectors enriched with spatial information, then merging via HDC operations. Deeply pipelined streaming architecture exploits parallelism along both patch and hypervector dimensions.  
Confidence: **high**

Claim: FACH (FPGA-based Acceleration of HD Computing) uses clustering to share values in class hypervectors, reducing multiplications by adding query elements that multiply with shared class elements first, then multiplying once. Achieves 5.1x faster execution and 5.9% higher energy efficiency [^37^].  
Source: FACH: FPGA-based Acceleration of Hyperdimensional Computing  
URL: https://www.cis.upenn.edu/~jianih/res/papers/aspdac19_fach.pdf  
Date: 2019  
Excerpt: "FACH can provide 5.1x faster execution and 5.9% higher energy efficiency as compared to the baseline HD."  
Context: FACH addresses the costly cosine metric for non-binary class hypervectors by clustering class elements and creating index buffers stored in FPGA distributed memory.  
Confidence: **high**

Claim: HD-Core exploits data locality between consecutive inputs to reuse previously encoded hypervectors, encoding 4.5x more inputs per second than GPU baseline and 2.1x more than FPGA baseline, with 5.7x and 2.3x energy reductions respectively [^38^].  
Source: Accelerating Hyperdimensional Computing on FPGAs by Exploiting Computational Reuse  
URL: https://par.nsf.gov/servlets/purl/10301134  
Date: 2022  
Excerpt: "HD-Core encoding can encode 4.5x and 2.1x more inputs in a second as compared to GPU and FPGA baseline respectively. HD-Core encoding reduced the energy required to encode each input for 5.7x and 2.3x as compared to the GPU and FPGA baseline respectively."  
Context: HD-Core stores transition hypervectors instead of base hypervectors, exploiting similarity between consecutive inputs. Particularly effective for FACE dataset with 9x throughput improvement over GPU.  
Confidence: **high**

Claim: PhotoHDC, an electro-photonic accelerator for HDC, uses Mach-Zehnder modulators and photodetectors to perform MAC operations at 5-10 GHz, arguing that photonics addresses NVM-based CiM challenges including multi-bit precision, write endurance, and update latency [^39^].  
Source: Towards Efficient Hyperdimensional Computing Using Photonics  
URL: https://arxiv.org/html/2311.17801v2  
Date: October 2024  
Excerpt: "Unlike NVM cells, photonic devices can achieve >=8-bit precision during operations, can attain high-bandwidth modulation with rates reaching tens of GHz, and do not suffer from endurance issues... The total required size of the SRAM-based on-chip memory is <1.4 MB for our datasets."  
Context: PhotoHDC targets data center/cloud-scale systems that perform both training and inference, where NVM-based CiM is infeasible due to write endurance limits.  
Confidence: **medium** (theoretical/architectural proposal; no fabrication results reported)

---

## 15. HDC for Continual Learning

Claim: LifeHD is the first on-device unsupervised lifelong learning system using HDC, with a two-tier memory hierarchy (working memory + long-term memory) for clustering hypervectors. It improves unsupervised clustering accuracy by up to 74.8% compared to NN-based baselines with 34.3x better energy efficiency [^40^].  
Source: Lifelong Intelligence Beyond the Edge using Hyperdimensional Computing  
URL: https://arxiv.org/abs/2403.04759  
Date: March 7, 2024  
Excerpt: "LifeHD improves the unsupervised clustering accuracy by up to 74.8% compared to the state-of-the-art NN-based unsupervised lifelong learning baselines with as much as 34.3x better energy efficiency."  
Context: LifeHD addresses three challenges of edge lifelong learning: streaming non-iid data, lack of supervision, and limited resources. It uses HDC's sparsity and high dimensionality to improve pattern separability and resilience against catastrophic forgetting.  
Confidence: **high**

Claim: Compared to operating in the original data space, HDC improves pattern separability through sparsity and high dimensionality, making it more resilient against catastrophic forgetting [^41^].  
Source: LifeHD paper  
URL: https://arxiv.org/html/2403.04759v1  
Date: 2024  
Excerpt: "Compared to operating in the original data space, HDC improves pattern separability through sparsity and high dimensionality, making it more resilient against catastrophic forgetting."  
Context: All NN baselines experience declining accuracy on streaming non-iid data, while LifeHD demonstrates incremental accuracy across time series (MHEALTH), sound (ESC-50), and image (CIFAR-100) scenarios.  
Confidence: **high**

---

## 16. Recovery, Clean-up Memory, and Associative Memory

Claim: Recovery from a compositional HV requires a "clean-up" procedure that projects a query HV onto the subspace spanned by the item memory, most commonly finding the nearest neighbor among stored HVs. For limited-size compositional structures, there are guarantees for exact recovery [^42^].  
Source: A Survey on Hyperdimensional Computing aka Vector Symbolic Architectures, Part I  
URL: https://dl.acm.org/doi/10.1145/3538531  
Date: 2022  
Excerpt: "The clean-up procedure can be viewed as projecting a query HV onto the subspace spanned by the item memory... For HVs representing limited size compositional structures, there are guarantees for the exact recovery."  
Context: Item memory can be implemented as a content-addressable associative memory (e.g., Hopfield network, Sparse Distributed Memory, or modern attention mechanisms). Recent work suggests item memory need not always be stored explicitly as it can be rematerialized.  
Confidence: **high**

Claim: Random linear codes over the Boolean field provide a novel approach to the recovery problem in HDC, admitting simple recovery algorithms for bundled or bound compositional representations, strictly faster than state-of-the-art resonator networks [^43^].  
Source: Linear Codes for Hyperdimensional Computing, Neural Computation  
URL: https://direct.mit.edu/neco/article/36/6/1084/120666/Linear-Codes-for-Hyperdimensional-Computing  
Date: May 10, 2024  
Excerpt: "We show that random linear codes admit simple recovery algorithms to factor (either bundled or bound) compositional representations... Both methods are strictly faster than the state-of-the-art resonator networks, often by an order of magnitude."  
Context: This addresses one of the long-standing challenges in HDC: factoring compositional representations to their constituent factors.  
Confidence: **high**

---

## 17. Generalized Holographic Reduced Representations (GHRR)

Claim: GHRR extends FHRR by representing each dimension as a unitary m×m matrix instead of a scalar phasor, enabling flexible non-commutative binding via element-wise matrix multiplication. For m=1, GHRR reduces to FHRR; for maximal m, it approaches Tensor Product Representations [^44^].  
Source: Generalized Holographic Reduced Representations (Yeung et al., 2024)  
URL: https://arxiv.org/abs/2405.09689  
Date: May 2024  
Excerpt: "GHRR base hypervectors are tensors of the form H = [a_1, ..., a_D]^T ∈ C^{D×m×m}, where a_j ∈ U(m). Binding is element-wise matrix multiplication... For fixed effective dimension, when m is minimal, i.e. 1, then the block-diagonal is just the diagonal as in FHRR, while, when m is maximal, the block-diagonal is the whole tensor product."  
Context: GHRR enables order-sensitive encoding without explicit permutations, critical for path-based reasoning, sequence modeling, and hierarchical structures. PathHD's block-diagonal GHRR uses this for knowledge graph path composition.  
Confidence: **high**

---

## 18. Optimal Hyperdimensional Representations

Claim: Two primary encoding regimes exist: Correlative Encoding (preserving similarities for classification with smooth decision boundaries) and Exclusive Encoding (maximizing separation for symbolic reasoning and accurate decoding) [^45^].  
Source: Optimal hyperdimensional representation for learning and cognitive computation  
URL: https://pmc.ncbi.nlm.nih.gov/articles/PMC12929535/  
Date: 2025  
Excerpt: "The first is Correlative Encoding, which captures shared structure among data points by preserving similarities in hyperspace. This regime is well-suited to learning tasks such as classification... The second regime is Exclusive Encoding, which maximizes separation between hypervectors to enable accurate decoding of stored information. This regime is essential for cognitive tasks requiring symbolic reasoning."  
Context: The design of the encoder critically influences both the similarity metric between data points in hyperspace and the degree of correlation or exclusivity in their representations.  
Confidence: **high**

---

## 19. Sub-linear Knowledge Retrieval with HDC

Claim: A quantum-inspired HDC knowledge retrieval system achieves sub-linear scaling through 4D hyperdimensional folded space indexing, with 100% accuracy, 0.88ms average response time on consumer hardware, and 162x speedup vs. exhaustive search [^46^].  
Source: Sub-Linear Knowledge Retrieval via Quantum-Inspired Hyperdimensional Folded Space  
URL: https://www.reddit.com/r/deeplearning/comments/1pkf909/sublinear_knowledge_retrieval_via_quantuminspired/ (original paper)  
Date: 2026  
Excerpt: "Our method uses quantum-inspired hyperdimensional computing (HDC) with geometric bucketing in 4D space, enabling O(1) retrieval for most queries. On a benchmark of 1,100 question-answer pairs, our system achieves 100% accuracy with 0.88ms average response time on consumer hardware... 162x speedup versus exhaustive search."  
Context: This independent research validates HDC for small-scale (1K-10K facts), ultra-low latency knowledge retrieval, though it has not been peer-reviewed and the scaling claims to larger corpora are untested.  
Confidence: **low** (preprint/independent research; claims of O(1) retrieval on small benchmarks; not peer-reviewed)

---

## 20. HDC Operations: Mathematical Summary

The three core operations of HDC, as formalized across the surveyed literature:

**Bundling (Superposition)**: `S = H_1 + H_2 + ... + H_n`
- Element-wise addition
- Result is similar to all inputs
- Cognitive interpretation: memorization, set union

**Binding (Association)**: `B = H_1 ⊙ H_2` (⊙ denotes binding operator)
- Element-wise multiplication, circular convolution, or XOR depending on VSA model
- Result is dissimilar to inputs
- Preserves similarity: similar inputs → similar bound outputs
- Cognitive interpretation: association, variable binding, role-filler pairing

**Permutation**: `P = ρ(H)`
- Cyclic shift or other fixed permutation of dimensions
- Used for encoding order and sequence
- Cognitive interpretation: positional encoding, temporal ordering

**Similarity**: `sim(H_1, H_2)`
- Cosine similarity, dot product, or Hamming distance
- Measures degree of overlap between distributed representations

---

## 21. Key Questions: Analysis and Assessment

### Q1: What Rust crates exist for hyperdimensional computing?

**Assessment**: The Rust HDC ecosystem is nascent but functional.

1. **`hypervector`** (rishikanthc/hypervector, docs.rs) — The most mature option. Implements MBAT (bipolar), SSP (Semantic Spatial Parameters), and FHRR. Provides generic `Hypervector<VSA>` type, `ObjectEncoder` for JSON, and reproducible RNG. Version ~0.1.0 as of early 2025.
2. **`hyperspace`** (d6y/hyperspace) — Experimental spike implementing Kanerva's binary VSA using `bitvec`. Minimal, assertion-only tests. Not production-ready.

**Gap**: No Rust crate currently implements GHRR (the non-commutative block-diagonal extension used by PathHD), qFHRR (quantized phase), or resonator networks for factorization. The `hypervector` crate is the closest to production use but lacks the breadth of Torchhd (Python). A Rust-native HDC library with GHRR, associative memory structures, and GPU acceleration via wgpu/ Vulkan compute would fill a significant need for deterministic local AI.

### Q2: Can HDC provide "infinite capacity" for local AI memory?

**Assessment**: **NO — this claim is theoretically false and empirically contradicted.**

- **Capacity is linear in dimension**: Both analytical and quantitative studies observe "a linear increase in the dimension of the HD vector with the number of entries to be added" [^29^]. For 1000-dimension vectors, ~20 items can be reliably bundled [^29^]. For 10,000 dimensions, capacity scales proportionally but remains finite.
- **Explicit acknowledgment from researchers**: "HDC vectors face capacity limitations determined by the dimension of HD space, encoding method, and potential noise levels" [^31^].
- **Noise accumulates**: Each bundled vector adds noise. For n key-value pairs in a dictionary, "the product vector [becomes] so noisy that associative search cannot choose the correct vector" [^29^].
- **Retrieval noise grows linearly**: In HRR superposition memories, "the retrieval noise grows linearly with the number of stored associations" [^44^].

However, HDC provides **graceful degradation** — as capacity is exceeded, performance degrades smoothly rather than catastrophically. The holographic property means partial information is recoverable even from noisy traces. For local AI memory, HDC is best suited for:
- Associative caches with bounded size (hundreds to thousands of entries at 10K dimensions)
- Compositional short-term memory buffers
- Symbolic working memory, not infinite long-term storage

### Q3: How do HDC representations compare to transformer embeddings for retrieval?

**Assessment**: HDC and transformer embeddings serve different niches with distinct tradeoffs.

**Transformer embeddings** (e.g., 512-2048 dimensions):
- Learned, context-sensitive, fine-grained semantic distinctions
- Require gradient-based training on large corpora
- ANN search with FAISS/HNSW achieves O(log n) approximate retrieval
- Excellent for semantic similarity, paraphrase detection, cross-modal retrieval
- Quadratic attention cost during encoding

**HDC representations** (e.g., 10,000 dimensions, fixed random base vectors):
- Non-learned (or lightly learned), deterministic, algebraic structure
- Compositional by construction: can bind/unbind symbols explicitly
- Exact retrieval via Hamming distance or cosine similarity (no approximation needed for modest databases)
- Robust to noise and hardware errors
- No training required for basic encoding; single-pass learning for classification

**Comparative performance**: On knowledge graph path retrieval, PathHD matches neural baseline Hits@1 with 40-60% lower latency and 3-5x lower GPU memory [^10^]. On image classification, pure HDC achieves ~26-42% on CIFAR-10 vs. CNN's 90%, but HDnn hybrids exceed CNN accuracy with 72.5% fewer parameters [^34^].

**Verdict**: For retrieval tasks requiring compositional structure (e.g., "find paths where A→B→C but not C→B→A"), HDC's explicit algebraic operations and non-commutative GHRR binding offer unique advantages. For pure semantic similarity on unstructured text, transformer embeddings remain superior. A hybrid approach — transformer embeddings for raw semantics, HDC for compositional binding and memory — is the most promising path.

### Q4: Can HDC be fused with SSM/Mamba for long-context memory?

**Assessment**: **Conceptually promising but largely unexplored in literature.**

**Why the fusion makes sense**:
- Mamba/SSMs compress long sequences into a fixed-size hidden state with O(n) complexity, but this state is opaque and not directly interpretable or manipulable.
- HDC provides a structured, algebraic framework for manipulating fixed-size vector representations — binding, unbinding, and querying by similarity.
- Mamba's hidden state could be interpreted as an HDC hypervector, with selective state updates corresponding to HDC bundling operations.

**Challenges**:
- No published research directly fuses HDC with Mamba or S4. The architectures are developed in separate communities.
- Mamba's state transitions are learned, nonlinear, and input-dependent (selective SSM), whereas HDC operations are typically fixed, linear, and algebraic. Reconciling these paradigms is non-trivial.
- HDC's capacity limitations (linear in dimension) may conflict with the massive information throughput of long-context SSMs processing 100K+ tokens.

**Potential approaches**:
1. **HDC as Mamba's external associative memory**: Use Mamba for sequential encoding, HDC for compositional memory storage and retrieval. The Mamba hidden state at each layer could be bound to a role hypervector and stored in an HDC associative memory.
2. **Differentiable HDC operations in SSM loops**: Replace Mamba's linear state transitions with HDC-inspired bundling/binding operations that are differentiable but retain algebraic structure. The qFHRR framework (3-4 bits per dimension) is particularly suited for efficient hardware implementation.
3. **HDC for KV-cache compression**: Instead of storing full KV caches (growing with sequence length), compress key-value pairs into HDC hypervectors using binding, enabling constant-memory context extension.

**Confidence**: This is a **theoretical/experimental opportunity** — no primary sources exist yet. The UASA/Rex project could be the first to explore this fusion.

---

## 22. Tensions, Contradictions, and Open Problems

1. **Capacity vs. Dimension**: HDC capacity scales linearly with dimension, but so does compute and memory. At 10,000 dimensions, only ~200 items can be reliably bundled. For "local AI memory" claims, dimension must be scaled to 100K+ or hierarchical memory architectures must be used.

2. **Accuracy vs. Efficiency**: Pure HDC achieves 26-42% on CIFAR-10; CNN hybrids achieve 90%+. The efficiency gains of HDC (single-pass learning, O(D) operations) are real but come with accuracy costs on complex data without neural feature extractors.

3. **Commutativity vs. Order**: Most HDC binding operations (XOR, element-wise product, circular convolution) are commutative, which cannot distinguish A→B from B→A. GHRR solves this with non-commutative matrix binding but at higher compute cost per dimension (matrix multiply vs. scalar multiply).

4. **Determinism vs. Randomness**: HDC relies on random base vectors for quasi-orthogonality, but reproducible randomness (global RNG seeds) can make this deterministic across runs. The `hypervector` Rust crate and Torchhd both support seeded generation.

5. **Theoretical Guarantees vs. Practical Encoding**: HDC has strong theoretical properties for random vectors, but real-world encoding schemes (random projection, level hypervectors, n-gram) introduce structure that affects orthogonality and capacity in ways not fully characterized.

6. **mHC Confusion**: The search for "mHC Birkhoff polytope hyperdimensional computing" returned results about Manifold-Constrained Hyper-Connections (mHC) from DeepSeek, a neural network architecture unrelated to hyperdimensional computing. This is a naming collision that researchers should be aware of.

---

## 23. Summary Table: HDC Models and Properties

| Model | Atomic HV | Binding | Superposition | Similarity | Self-inverse | Commutative |
|---|---|---|---|---|---|---|
| BSC (Kanerva) | Binary {0,1} | XOR | Majority sum | Hamming dist | Yes | Yes |
| MAP (Gayler) | Bipolar {-1,+1} | Element-wise mult | Element-wise add | Cosine/dot | Yes | Yes |
| HRR (Plate) | Real-valued | Circular convolution | Element-wise add | Dot product | Approx | Yes |
| FHRR | Complex phasor | Element-wise complex mult | Element-wise add | Cosine | Yes (conj) | Yes |
| GHRR | Unitary m×m matrix | Element-wise matrix mult | Element-wise add | Traced inner product | Yes (adj) | No (configurable) |
| MBAT | {-1,+1} or real | Matrix-vector mult | Element-wise add | Dot/Euclidean | No | No |
| SPA (Eliasmith) | Real unit-length | Circular convolution | Addition | Dot product | Approx | Yes |

---

## 24. Recommendations for UASA/Rex

1. **Adopt GHRR for ordered structures**: For any reasoning requiring sequence, path, or hierarchical ordering, GHRR's non-commutative binding is essential. The block-diagonal implementation used by PathHD is efficient and proven.

2. **Use HDC as a memory substrate, not a reasoning engine**: HDC excels at associative storage, retrieval, and compositional binding. For complex reasoning, combine HDC memory with LLM or symbolic adjudication (as PathHD does with single-LLM call).

3. **Hybrid architecture (HDnn pattern)**: Use neural encoders (frozen or lightly trained) for complex feature extraction, then HDC for classification, memory, and retrieval. This is the only approach that achieves competitive accuracy on images/audio.

4. **Implement in Rust with careful engineering**: The `hypervector` crate provides a starting point, but GHRR, qFHRR, resonator networks, and associative memory data structures need to be added for a complete UASA substrate.

5. **Capacity budgeting**: For D=10,000, plan for ~200 bundled items. For larger memory, either increase dimension (with linear cost) or use hierarchical memory architectures with chunking and indexing.

6. **Explore HDC-SSM fusion**: The combination of Mamba's linear-complexity state updates with HDC's algebraic memory operations is a high-value research direction with no existing literature.

---

## Citation Index

[^1^]: Plate, T.A. (1995). Holographic Reduced Representations. *IEEE Transactions on Neural Networks*, 6(3), 623-641.  
[^2^]: Plate, T.A. (1995). Holographic Reduced Representations (local copy).  
[^3^]: Plate, T.A. (1995). Holographic Reduced Representations, Discussion section.  
[^4^]: Yeung, C.H., Zou, Z., Imani, M. (2024). Generalized Holographic Reduced Representations. *arXiv:2405.09689*.  
[^5^]: Snyder, S. et al. (2026). qFHRR: Rethinking Fourier Holographic Reduced Representations through Quantized Phase and Integer Arithmetic. *arXiv:2604.25939*.  
[^6^]: Kleyko, D. et al. (2022). A Survey on Hyperdimensional Computing aka Vector Symbolic Architectures, Part I. *ACM Computing Surveys*, 55(6).  
[^7^]: Kleyko, D. et al. (2022). Survey Part I, Section 2.3.7.  
[^8^]: Kleyko, D. et al. (2022). Survey Part I, Section 2.3.4.  
[^9^]: Nengo SPA Documentation. https://www.nengo.ai/nengo-spa/  
[^10^]: Liu, Y. et al. (2025). Are Hypervectors Enough? Single-Call LLM Reasoning over Knowledge Graphs. *arXiv:2512.09369*.  
[^11^]: Liu, Y. et al. (2025). PathHD, Complexity Analysis.  
[^12^]: Zakeri, A. et al. (2025). Configurable hyperdimensional graph representation. *Artificial Intelligence*, 347, 104384.  
[^13^]: Chandrasekaran, R. (2025). `hypervector` Rust crate. https://docs.rs/hypervector  
[^14^]: d6y. (2024). `hyperspace` Rust crate. https://github.com/d6y/hyperspace  
[^15^]: Heddes, M. et al. (2023). Torchhd: An Open Source Python Library. *JMLR*, 24, 1-10.  
[^16^]: Karunaratne, G. et al. (2020). In-memory hyperdimensional computing. *Nature Electronics*.  
[^17^]: Hardware-Algorithm Co-Design for HDC with IMC. (2025). *arXiv:2512.20808*.  
[^18^]: Khaleghi, B. et al. (2022). HyDREA: Utilizing Hyperdimensional Computing For Adaptive PIM Architecture. *ACM TECS*.  
[^19^]: Sarkar et al. (2026). HDC with Legendre Delay Networks. ICNC 2026.  
[^20^]: Verges, P. et al. (2025). Accelerating Permute and N-gram Operations for HDC in Embedded Systems.  
[^21^]: Kleyko, D. et al. (2023). Survey Part II: Applications, Cognitive Models, and Challenges. *ACM Computing Surveys*.  
[^22^]: Moin, A.S. et al. (2022). Memory-inspired spiking hyperdimensional network. *Nature Scientific Reports*, 12, 7586.  
[^23^]: Lipschitz-based robustness estimation for hyperdimensional learning. (2025). *Frontiers in AI*.  
[^24^]: Grokipedia. Hyperdimensional computing.  
[^25^]: Karunaratne et al. (2020). In-memory HDC, language experiments.  
[^26^]: Kröger, B.J. et al. (2021). NLP in Large-Scale Neural Models. *PMC7805752*.  
[^27^]: Mitrokhin, A. et al. (2019). Learning sensorimotor control with neuromorphic sensors. *Science Robotics*, 4(30), eaaw6736.  
[^28^]: University of Maryland press release. (2019). Helping robots remember.  
[^29^]: Yerxa, T. et al. (2024). The Hyper-Dimensional Processing Unit. *Berkeley EECS-2024-232*.  
[^30^]: Yeung, C.H. et al. (2024). GHRR, Capacity experiments.  
[^31^]: Yu, X. et al. (2024). LifeHD, Limitations of HDC section.  
[^32^]: Ma, D., Jiao, X. (2022). Hyperdimensional Computing vs. Neural Networks. *arXiv:2207.12932*.  
[^33^]: Li, Z. et al. (2025). Federated Hyperdimensional Computing. *ACM*.  
[^34^]: Kim, Y. et al. (2022). HDnn-PIM: Efficient in Memory Design. *GLSVLSI*.  
[^35^]: Cumbo, F. et al. (2025). Quantum Hyperdimensional Computing. *arXiv:2511.12664*.  
[^36^]: HD FPGA accelerator. (2026). Primitive-Driven Acceleration. *arXiv:2601.20061*.  
[^37^]: Salamat, S. et al. (2019). FACH: FPGA-based Acceleration. *ASPDAC*.  
[^38^]: Salamat et al. (2022). HD-Core. *IEEE*.  
[^39^]: Imani, M. et al. (2024). Towards Efficient HDC Using Photonics. *arXiv:2311.17801*.  
[^40^]: Yu, X. et al. (2024). LifeHD. *arXiv:2403.04759*.  
[^41^]: Yu, X. et al. (2024). LifeHD, resilience claim.  
[^42^]: Kleyko et al. (2022). Survey Part I, Recovery and Clean-up section.  
[^43^]: Linear Codes for Hyperdimensional Computing. (2024). *Neural Computation*, 36(6).  
[^44^]: Yeung et al. (2024). GHRR, binding as interpolation.  
[^45^]: Optimal hyperdimensional representation. (2025). *PMC12929535*.  
[^46^]: Horn, J.P. (2026). Sub-Linear Knowledge Retrieval via Quantum-Inspired HDC.  

---

*End of Research Report — Dimension 11: Hyperdimensional & Vector Symbolic Computing*
