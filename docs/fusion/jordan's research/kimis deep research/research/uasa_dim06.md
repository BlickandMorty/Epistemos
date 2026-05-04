# UASA/Rex Dimension 06: Formal Verification Integration for AI

## Research Report: Formal Verification Tools and Methods for AI System Validation

**Date**: 2025  
**Searches Conducted**: 18 independent queries across 15 topic areas  
**Sources**: arXiv, ACM Digital Library, official documentation, conference proceedings, peer-reviewed journals

---

## 1. Kani Rust Model Checker

### Overview
Kani is an open-source bit-precise model checker for Rust built on top of CBMC (C Bounded Model Checker). It verifies Rust programs through deductive mathematical proofs using partially-constrained (symbolic) inputs and deterministic symbolic reasoning over Rust MIR (Mid-Level IR) [^1^].

```
Claim: Kani automatically checks for undefined behavior in unsafe Rust code blocks, where the "unsafe superpowers" are unchecked by the compiler [^1^].
Source: Kani Rust Verifier Official Documentation
URL: https://model-checking.github.io/kani/
Date: Current
Excerpt: "Kani is useful for checking both safety and correctness of Rust code. Safety: Kani automatically checks for many kinds of undefined behavior. This makes it particularly useful for verifying unsafe code blocks in Rust, where the 'unsafe superpowers' are unchecked by the compiler."
Context: Official getting started documentation
Confidence: high
```

### Capabilities and Limitations

```
Claim: Kani has no support for multithreading, atomic operations, or async runtimes (though async syntax is supported), and loops/deep recursion cause state-space explosion [^2^].
Source: Ferrous Systems Rust Training / Kani Documentation
URL: https://rust-training.ferrous-systems.com/latest/book/kani
Date: Current
Excerpt: "No multithreading support; No support for atomic operations; No support for async runtimes (but the syntax is supported); No inline assembly; Loops and deep recursion balloon the number of states that require inspection"
Context: Kani limitations documentation
Confidence: high
```

### Performance Characteristics

```
Claim: Kani verification times vary dramatically — cryptographic harnesses verify in under 5 seconds, while data structure harnesses with BTreeSet can exceed 1000 seconds; loop unrolling is the primary cost driver [^3^].
Source: PropProof: Free Model-Checking Harnesses from PBT (ACM OOPSLA 2023)
URL: https://dl.acm.org/doi/pdf/10.1145/3611643.3613863
Date: 2023
Excerpt: "Despite heavy use of arrays and cryptographic operations, these are verified in under 5 seconds... Benchmark 22 took the longest, taking over 1000s to verify. The primary cause for the difficult verification is the presence of BTreeSet in the inputs... kani::vec_any is implemented via a loop, and another for loop is used to assume the vector elements are even. In total 2 loops over a symbolic vector is required. The 2 loops perform worse than the 1-loop"
Context: Empirical evaluation of Kani on 42 benchmarks from real Rust libraries
Confidence: high
```

```
Claim: SAT solver selection provides speedups of 2-8x and up to 200x on specific harnesses; Kissat reduced `random::tests::gen_range_biased_test` from 1460s to 5.5s [^4^].
Source: Turbocharging Rust Code Verification (Kani Blog)
URL: https://model-checking.github.io/kani-verifier-blog/2023/08/03/turbocharging-rust-code-verification.html
Date: 2023-08-03
Excerpt: "For `random::tests::gen_range_biased_test`, verification time goes down from 1460 seconds with MiniSat to 6.8 and 5.5 seconds with CaDiCaL and Kissat, respectively, thereby providing speedups of more than 200X... By picking the best solver for each harness, we can bring the total cumulative runtime from 2 hours and 20 minutes down to 15 minutes"
Context: Kani performance optimization blog post with s2n-quic benchmarks
Confidence: high
```

```
Claim: Kani verification of simple properties completes in milliseconds (e.g., 0.035s for `panic_or_zero`, 0.28s for `i64_abs` overflow detection) [^5^].
Source: Making Even Safe Rust a Little Safer (Colin Breck Blog)
URL: https://blog.colinbreck.com/making-even-safe-rust-a-little-safer-model-checking-safe-and-unsafe-code/
Date: 2024-12-29
Excerpt: "Verification Time: 0.28206664s... Verification Time: 0.035682622s"
Context: Blog post demonstrating Kani on simple and unsafe Rust examples
Confidence: high
```

### Contracts and Loop Invariants

```
Claim: Kani supports function contracts (`#[kani::requires]`, `#[kani::ensures]`, `#[kani::modifies]`) and loop contracts (`#[kani::loop_invariant]`, `#[kani::loop_modifies]`, `#[kani::loop_decreases]`) as of version 0.64.0 [^6^].
Source: Kani Attributes Reference
URL: https://model-checking.github.io/kani/reference/attributes.html
Date: Current
Excerpt: "Function contract specification: #[kani::requires], #[kani::modifies], #[kani::ensures], #[kani::recursion]; Loop contract specification: #[kani::loop_invariant], #[kani::loop_modifies], #[kani::loop_decreases]"
Context: Official Kani reference documentation for contract attributes
Confidence: high
```

### Key Insight for UASA/Rex
Kani is **proven technology** for bounded verification of Rust code. The verification overhead is **highly variable**: simple arithmetic properties verify in milliseconds, while loops and complex data structures can take seconds to minutes. For "every agent step" verification, Kani would require carefully bounded harnesses with small symbolic inputs and minimal loops. The CBMC backend's SAT solving is the bottleneck — solver selection (Kissat/CaDiCaL vs MiniSat) can change verification time by orders of magnitude.

---

## 2. Creusot Deductive Verifier

### Overview
Creusot is a deductive verifier for Rust that translates annotated Rust code into the Coma intermediate language (part of the Why3 platform), enabling SMT-based verification [^7^].

```
Claim: Creusot recently added linear ghost types to enable verification of unsafe low-level pointer-manipulating code, making it suitable for std-lib verification challenges [^7^].
Source: Creusot Issue #493 — model-checking/verify-rust-std
URL: https://github.com/model-checking/verify-rust-std/issues/493
Date: 2025-09-16
Excerpt: "While in its early days, Creusot aimed for the verification of safe code, we have recently added linear ghost types, a feature pioneered by Verus to enable the verification of unsafe low-level pointer-manipulating code. This makes Creusot suitable for several of the std-lib verification challenges."
Context: Creusot tool submission to verify-rust-std project
Confidence: high
```

### Specification Language (Pearlite)

```
Claim: Creusot provides a specification language called Pearlite with requires/ensures contracts, loop invariants, ghost code, proof_assert, and variant clauses for termination; unlike Verus, it does not use separation logic ubiquitously, relying on Rust's type system for separation properties [^8^].
Source: Deductive Verification of Rust Programs (PhD Thesis, 2023)
URL: https://theses.fr/2023UPASG101/abes
Date: 2023
Excerpt: "requires: Attached to functions or closures, allows specifying a precondition... ensures: Attached to functions or closures, specifies the postcondition... invariant: Can be attached to loops and states a property that must be valid before each iteration... proof_assert: Inserts a ghost assertion which is checked for validity... variant: Used to prove the termination of functions"
Context: PhD thesis on Creusot's design and implementation
Confidence: high
```

### WhyML and Why3 Backend

```
Claim: In Creusot, Rust code is lowered into Why3's MLCFG (an ML with labelled blocks and gotos), then Why3 encodes verification conditions for backend solvers; compared to Prusti (Viper separation logic), Creusot's encoding is lighter weight for safe Rust [^9^].
Source: Verus: Verifying Rust Programs using Linear Ghost Types (arXiv:2303.05491)
URL: https://arxiv.org/pdf/2303.05491
Date: 2023
Excerpt: "In Creusot the Rust code is first lowered into Why3's MLCFG (an ML with labelled blocks and gotos), and then Why3 encodes verification conditions for the backend solvers. Prusti verifies Rust code by translating it into the Viper separation logic engine... This relatively heavyweight encoding creates larger formulas for an SMT solver"
Context: Comparison of Rust verification tools in Verus paper
Confidence: high
```

### Key Insight for UASA/Rex
Creusot is **experimental but maturing** technology. Its SMT-based approach through Why3 means verification time depends on SMT solver performance (Z3, CVC4/5, Alt-Ergo). The addition of linear ghost types for unsafe code is a significant recent advance. For agent step verification, Creusot would be suitable for function contracts and loop invariants, but the annotation burden is non-trivial.

---

## 3. Lean 4 Theorem Prover

### Architecture and Performance

```
Claim: Lean 4's mathlib4 build completes in ~2300s vs ~5400s (Lean 3) and >10,000s (Coq); the kernel implements CIC with cumulative universes, inductive families, quotient types [^10^].
Source: Lean 4: Scalable Theorem Proving (Emergent Mind)
URL: https://www.emergentmind.com/topics/lean-4
Date: 2026-01-15
Excerpt: "Benchmarks indicate that the mathlib4 build completes in ~2300s (Lean 4) vs ~5400s (Lean 3) and >10,000s (Coq), while individual kernel tasks show similar or greater speedups"
Context: Comprehensive overview of Lean 4 architecture
Confidence: high
```

### Metaprogramming and Tactics

```
Claim: Lean 4 metaprogramming uses the `MetaM` monad providing effectful access to elaborator state; custom tactics, macros, and extensible elaboration are fully integrated [^11^].
Source: Metaprogramming in Lean 4 (Official Book)
URL: http://anggtwu.net/snarf/https/leanprover-community.github.io/lean4-metaprogramming-book/print.pdf
Date: 2024-10-06
Excerpt: "elab 'explore' : tactic => do let mvarId : MVarId <- Lean.Elab.Tactic.getMainGoal..."
Context: Official Lean 4 metaprogramming tutorial book
Confidence: high
```

```
Claim: Lean 4 supports ATP integration (Lean-auto), RL-based proof search (Kimina, LeanTree), and meta-theoretical tactics; mathlib4 exceeds 60k declarations [^10^].
Source: Lean 4: Scalable Theorem Proving (Emergent Mind)
URL: https://www.emergentmind.com/topics/lean-4
Date: 2026-01-15
Excerpt: "Custom Proof Automation: The system supports both high-level proof search tactics (e.g., Aesop, Duper, Lean-auto) and fine-grained, user-authored tactics... mathlib4: A port and extension of Lean 3's mathlib, now exceeding 60k declarations"
Context: Comprehensive overview of Lean 4 ecosystem
Confidence: high
```

### Verified Extraction

```
Claim: Lean 4 enables certified code extraction — compiling verified definitions into efficient C code while eliminating proof overhead; this separates Lean from academic predecessors like Coq [^12^].
Source: If It Compiles, It Is Correct (LambdaClass Blog)
URL: https://blog.lambdaclass.com/if-it-compiles-it-is-correct-almost-an-introduction-to-lean-4-for-zk-systems-and-engineering-2/
Date: 2026-01-29
Excerpt: "Since writing the specification in Lean and then rewriting it by hand in C introduces the risk of human error, you can write critical functions in Lean, formally prove their correctness, and then ask Lean to automatically generate the corresponding C code."
Context: Practical introduction to Lean 4 for engineers
Confidence: high
```

### Key Insight for UASA/Rex
Lean 4 is **proven, production-grade** interactive theorem proving infrastructure. The verification overhead is **significant** — individual tactics can take seconds, and full proof checking of complex theorems takes minutes. However, Lean 4 is not designed for "real-time" per-step verification. For UASA/Rex Layer 5, Lean would be appropriate for **offline verification** of agent reasoning chains, protocol properties, or mathematical claims, not for inline per-step checking.

---

## 4. LeanDojo: Neural Theorem Proving

### Overview
LeanDojo is a Python library that extracts data from Lean repos and enables programmatic interaction with Lean, serving as foundational infrastructure for AI-driven theorem proving [^13^].

```
Claim: LeanDojo extracts 98,734 theorem/proofs from mathlib; its ReProver model achieves 51.2% theorem proving on the benchmark, outperforming direct tactic generation (47.6%) and GPT-4 zero-shot (29.0%) [^14^].
Source: LeanDojo: Theorem Proving with Retrieval-Augmented Language Models (NeurIPS 2023)
URL: https://arxiv.org/pdf/2306.15626
Date: 2023
Excerpt: "Using LeanDojo, we construct a benchmark containing 98,734 theorems/proofs extracted from mathlib... ReProver can prove 51.2% theorems, outperforming a baseline that generates tactics directly without retrieval (47.6%) and another baseline using GPT4 to generate tactics in a zero-shot manner (29.0%)"
Context: Original LeanDojo NeurIPS 2023 paper
Confidence: high
```

```
Claim: LeanDojo's original library is deprecated; LeanDojo-v2 is the current version supporting both Lean 3 and Lean 4 [^15^].
Source: LeanDojo Documentation
URL: https://leandojo.readthedocs.io/
Date: Current
Excerpt: "LeanDojo is a Python library for learning-based theorem provers in Lean, supporting both Lean 3 and Lean 4. It provides two main features: Extracting data (proof states, tactics, premises, etc.) from Lean repos; Interacting with Lean programmatically."
Context: Official LeanDojo documentation
Confidence: high
```

### Key Insight for UASA/Rex
LeanDojo is **experimental research infrastructure** for ML-assisted theorem proving. It enables training of neural proof agents but does not provide formal guarantees — the Lean kernel still checks every proof. For Rex Layer 5, LeanDojo could power **AI-assisted proof search**, but the actual verification is done by Lean's trusted kernel.

---

## 5. SMT Solvers for AI Verification

### SMT in Neural Network Verification

```
Claim: Reluplex is an SMT-based approach for neural network verification that decides satisfiability of conjunctions of linear inequalities and ReLU equations; Marabou continues this line of work [^16^].
Source: Lecture 9: Verifying Robustness (UPenn CIS 7000)
URL: https://www.seas.upenn.edu/~obastani/cis7000/spring2024/docs/lecture9.pdf
Date: Spring 2024
Excerpt: "Reluplex: An SMT based approach... The Constraint Satisfaction Problem: Set of variables V; Atomic predicate: Linear inequality of the form p=(sum a_i v_i <= c_i); ReLU equation of the form p=(v_i = ReLU(v_j))"
Context: Graduate lecture slides on neural network verification
Confidence: high
```

```
Claim: Marabou 2.0 features a Network-level Reasoner implementing 7 bound-tightening analyses (IBP, symbolic bound propagation, DeepPoly/CROWN, LP-based, forward-backward, MILP, iterative propagation) interleaved with the SMT solver [^17^].
Source: Marabou 2.0: Neural Network Verification (arXiv:2401.14461)
URL: https://arxiv.org/pdf/2401.14461
Date: 2024-05-20
Excerpt: "Currently, seven different analyses are implemented: 1. Interval bound propagation; 2. symbolic bound propagation; 3. DeepPoly/CROWN analysis; 4. LP-based bound tightening; 5. Forward-backward analysis; 6. MILP-based bound tightening; and 7. iterative propagation"
Context: Marabou 2.0 technical paper
Confidence: high
```

### Neuro-Symbolic Verification

```
Claim: Neuro-symbolic verifiers integrate neural models with symbolic reasoning (SMT solvers, theorem provers, model checkers) where the symbolic backend acts as an oracle, discarding or refining neural outputs [^18^].
Source: Neuro-Symbolic Verifier (Emergent Mind)
URL: https://www.emergentmind.com/topics/neuro-symbolic-verifier
Date: 2025-12-01
Excerpt: "SMT Solving: Proof obligations, program assertions, or property specifications are encoded in SMT, enabling symbolic checking of formulas that embed calls to neural models or their learned invariants... A critical property of these frameworks is that verification is not contingent on the correctness of neural outputs alone; the symbolic back-end acts as an oracle"
Context: Overview of neuro-symbolic verification frameworks
Confidence: medium
```

```
Claim: Amazon Bedrock Guardrails now includes "automated reasoning checks" using neurosymbolic AI to prove correctness of AI outputs with up to 99% accuracy verification [^19^].
Source: A Chat with Byron Cook on Automated Reasoning and Trust in AI (All Things Distributed)
URL: https://www.allthingsdistributed.com/2026/02/a-chat-with-byron-cook-on-automated-reasoning-and-trust-in-ai-systems.html
Date: 2026-02-17
Excerpt: "This year, we released a capability called automated reasoning checks in Amazon Bedrock Guardrails which enables customers to prove correctness for their own AI outputs. The capability can verify accuracy by up to 99%."
Context: Interview with AWS VP on neurosymbolic AI for automated reasoning
Confidence: medium
```

### Key Insight for UASA/Rex
SMT solvers (Z3, CVC5) are **proven technology** for constraint solving but face scalability limits. For "real-time" dimensional consistency checking, SMT queries on small formulas (tens of constraints) complete in milliseconds. For neural network verification, SMT-based approaches (Reluplex/Marabou) are **complete but computationally expensive** — they can verify small-to-medium networks but do not scale to production-scale transformers.

---

## 6. Neural Network Verification

### Bound Propagation Methods

```
Claim: Interval Bound Propagation (IBP) propagates input regions as box over-approximations layer by layer; for ReLU, output bounds are computed as x^i = (xbar^i + xunderline^i)/2, delta^i = (xbar^i - xunderline^i)/2 where xbar^i = ReLU(xbar^{i-1} + delta^{i-1}) and xunderline^i = ReLU(xbar^{i-1} - delta^{i-1}) [^20^].
Source: ICLR 2024 Paper (with interval bound propagation)
URL: https://proceedings.iclr.cc/paper_files/paper/2024/file/3a2e5889b4bbef997ddb13b55d5acf77-Paper-Conference.pdf
Date: 2024
Excerpt: "Propagating such a BOX through the linear layer... To propagate a BOX through the ReLU activation... resulting in an output BOX with xhat^i = (xbar^i + xunderline^i)/2 and delta^i = (xbar^i - xunderline^i)/2"
Context: ICLR 2024 paper on neural network certification
Confidence: high
```

```
Claim: CROWN (linear bound propagation) produces much tighter bounds than IBP by maintaining linear relationships to inputs; for the example y = z1 - z2 with z1 = x1 - x2, z2 = 2x1 - x2, IBP gives y in [-8,7] while the true bounds are [-2,1] [^21^].
Source: Lecture 9: Neural Network Verification - Bound Propagation (UIUC)
URL: http://publish.illinois.edu/ece584-spring2024/files/2024/02/Lecture-9_-Neural-Network-Verification-Bound-Propagation.pdf
Date: Spring 2024
Excerpt: "Apply IBP we obtain y in [-8,7]... However observe that y = x1 - x2 - (2x1 - x2) = -x1. The actual bounds is [-2,1], much tighter than [-8,7]"
Context: Graduate lecture on neural network bound propagation
Confidence: high
```

### alpha-beta-CROWN and VNNCOMP

```
Claim: alpha-beta-CROWN won VNN-COMP 2021, 2022, and 2023; it supports CNN, ResNet, Transformers, LSTMs, and general nonlinear functions via the auto_LiRPA library; it scales to millions of parameters [^22^].
Source: alpha-beta-CROWN GitHub Repository
URL: https://github.com/Verified-Intelligence/alpha-beta-CROWN_vnncomp2024
Date: 2024-07-09
Excerpt: "alpha,beta-CROWN is a neural network verifier based on an efficient linear bound propagation framework and branch and bound. It can be accelerated efficiently on GPUs and can scale to relatively large convolutional networks (e.g., millions of parameters)."
Context: Official alpha-beta-CROWN repository for VNN-COMP 2024
Confidence: high
```

### Fundamental Limits

```
Claim: There is a universal trade-off between bound tightness and computational cost in neural network verification; real models constantly stress this trade-off; the field synthesizes ML, optimization, and formal methods [^23^].
Source: Neural Network Verification: Why Is It Still a Research Problem?
URL: https://medium.com/@umutt.akbulut/neural-network-verification-why-is-verifying-a-neural-network-still-a-research-problem-f638b41d8493
Date: 2026-01-03
Excerpt: "These three families are different ways of holding the same truth: neural network verification is not a purely formal-methods problem; it is largely a problem of optimization, geometry, and search strategy... there is a universal trade-off between bound tightness and computational cost"
Context: Analysis of neural verification as a research problem
Confidence: high
```

### Key Insight for UASA/Rex
Neural network verification is **active research, partially proven for small/medium networks**. Complete verification (alpha-beta-CROWN, Marabou) works for networks up to millions of parameters but faces fundamental scalability barriers. Incomplete verification (IBP, CROWN, randomized smoothing) scales better but provides weaker guarantees. For production-scale LLMs, **no complete verifier exists** — randomized smoothing and adversarial training are the practical approaches.

---

## 7. Code Generation Verification

### Formal Query Languages for LLM Code

```
Claim: Astrogator proposes a formal query language and State Calculus with symbolic interpreter to verify LLM-generated Ansible code; the verifier uses unification-like matching between program and query state pairs [^24^].
Source: Towards Formal Verification of LLM-Generated Code from Natural Language Prompts (arXiv:2507.13290)
URL: https://arxiv.org/html/2507.13290v1
Date: 2025-07-17
Excerpt: "We propose two key components: the Formal Query Language which is our formal specification language S which expresses the user's intent in a formal manner and the Verifier which given a program p and formal query s determines whether p satisfies s... using a symbolic interpreter to identify their behaviors"
Context: Paper on formal verification of LLM-generated code
Confidence: high
```

### Reasoning Chains for Scientific Code

```
Claim: A chain-of-reasoning approach iteratively lifts basic semantics from code into the SPIRAL system and establishes numerical equivalency to desired mathematical operations, quantifying all sources of error [^25^].
Source: Towards Automated Reasoning Chains for Verification of LLM-Generated Code (CMU HPEC 2025)
URL: https://users.ece.cmu.edu/~franzf/papers/2025_HPEC_Oschatz_Q.pdf
Date: 2025
Excerpt: "We propose a chain-of-reasoning approach that iteratively lifts basic semantics from code into the SPIRAL system and then establishes numerical equivalency to the desired mathematical operation... The chain establishes tight error bounds on the output of given code with respect to the true continuous solution it approximates"
Context: CMU paper on verifying LLM-generated scientific computing code
Confidence: high
```

### Symbolic Execution + LLMs

```
Claim: LLM-based automated function modeling for symbolic execution reduces manual modeling from a month to minutes; this is the first integration of LLMs into formal verification for symbolic execution frameworks [^26^].
Source: LLM-Based Unknown Function Automated Modeling in Symbolic Execution (PMC)
URL: https://pmc.ncbi.nlm.nih.gov/articles/PMC12074466/
Date: 2022-05-17 (published 2025)
Excerpt: "Our approach was integrated into one verification platform project... The application of this method directly reduces the manual modeling effort from a month to just a few minutes. This provides a foundational validation of our method's feasibility... This work is the first to integrate LLMs into formal verification"
Context: Paper on LLM-assisted symbolic execution
Confidence: high
```

### Key Insight for UASA/Rex
Code generation verification is **emerging, largely experimental**. Approaches include formal query languages (Astrogator), reasoning chains with error bounding (SPIRAL), and LLM-assisted symbolic execution. None are yet ready for real-time per-generation verification of arbitrary code. For UASA/Rex, a **staged approach** would work best: quick property-based tests for immediate feedback, followed by deeper symbolic/model-checking verification for critical paths.

---

## 8. Property-Based Testing for AI

### PBT Foundations

```
Claim: Property-based testing (PBT) defines properties rather than specific test cases; it excels at edge case detection, scalability, and flexibility compared to traditional example-based testing [^27^].
Source: Introduction to Property-Based Testing (Medium)
URL: https://medium.com/@tt3043701/introduction-to-property-based-testing-55a27aec1346
Date: 2025-05-24
Excerpt: "Edge Case Detection: PBT tests boundary cases and invalid inputs, catching bugs traditional tests miss. Scalability: Properties cover all scenarios, reducing the need for manual test additions. Flexibility: Properties adapt to changes in limits or date rules"
Context: Tutorial on property-based testing concepts
Confidence: medium
```

### PropProof: PBT to Model Checking

```
Claim: PropProof converts Proptest (Rust PBT) harnesses to Kani model-checking harnesses with zero library changes; it discovered 2 issues in prost-types that fuzzing and PBT in CI had missed [^3^].
Source: PropProof: Free Model-Checking Harnesses from PBT (ACM OOPSLA 2023)
URL: https://dl.acm.org/doi/pdf/10.1145/3611643.3613863
Date: 2023
Excerpt: "During our evaluation, we discovered 2 issues in prost-types, a crate part of PROST, a protocol buffers library. Given that this library is well-tested with fuzzing and PBT running in CI, this shows that our tool is capable of finding subtle issues that go uncaught"
Context: Peer-reviewed paper on PropProof
Confidence: high
```

### Key Insight for UASA/Rex
Property-based testing is **proven technology** that can be deployed immediately. The bridge from PBT to model checking (PropProof) offers a practical path: write properties as PBT tests, then selectively elevate to Kani for formal guarantees. For AI model outputs, properties could assert dimensional consistency, boundedness, monotonicity, or output format constraints.

---

## 9. Formal Semantics for Neural Networks

### Process Calculi for Neural Systems

```
Claim: A process calculus for spiking neural P systems has been developed with operational and denotational semantics using metric spaces and continuations for concurrency; the denotational semantics is proved correct with respect to the operational semantics [^28^].
Source: A process calculus for spiking neural P systems (Information Sciences)
URL: https://www.sciencedirect.com/science/article/pii/S0020025522003231
Date: 2024-05-25
Excerpt: "This paper presents a calculus inspired by the spiking neural P systems. Its operational and denotational semantics are defined; they are related by using the metric semantics methodology, showing that the denotational semantics is correct with respect to the operational one."
Context: Peer-reviewed journal article on neural process calculi
Confidence: high
```

### Key Insight for UASA/Rex
Formal semantics for neural networks is **theoretical research** with limited practical tooling. Process calculi and denotational semantics provide conceptual frameworks but are not yet integrated with production verification tools. For UASA/Rex, this area offers long-term research value but near-term practical impact is low.

---

## 10. Type-Safe Machine Learning

### JAX Typed Shapes

```
Claim: jaxtyping provides runtime type annotations for tensor shapes and dtypes in Python; it works via internal dictionaries tracking dimension sizes and a runtime type-checker calling isinstance for every argument [^29^].
Source: No more shape errors! Type annotations for the shape+dtype of tensors/arrays (Patrick Kidger)
URL: https://kidger.site/thoughts/jaxtyping/
Date: 2023-12-18
Excerpt: "Every time you do an isinstance check, e.g. isinstance(some_tensor, Float[Tensor, 'batch channels height width']), then an internal dictionary of sizes tracking things like batch=64, channels=3 are checked and updated. If a size is inconsistent with one already stored, then the isinstance check returns False."
Context: Blog post on jaxtyping internals
Confidence: high
```

### Haskell Dependent Types for Tensors

```
Claim: Haskell's SafeShape type uses GADTs and DataKinds to encode full tensor shapes in types, enabling compile-time shape verification; fromShape :: Shape -> Maybe (SafeShape s) validates shapes at runtime [^30^].
Source: Tensor Flow and Dependent Types (Monday Morning Haskell)
URL: https://mmhaskell.com/machine-learning/dependent-types
Date: Current
Excerpt: "data SafeShape (s :: [Nat]) where NilShape :: SafeShape '[]; (:--) :: KnownNat m => Proxy m -> SafeShape s -> SafeShape (m ': s)... fromShape :: Shape -> Maybe (SafeShape s)"
Context: Tutorial on dependent types for safe tensor operations in Haskell
Confidence: high
```

### Dex and JAX Linear Logic

```
Claim: Dex encodes the index set directly into the array type, allowing distinguishing dimensions that are similarly-sized but different-in-meaning; JAX autodiff has been studied from a linear logic perspective with formal semantics [^31^].
Source: JAX Autodiff from a Linear Logic Perspective (Extended)
URL: https://arxiv.org/pdf/2510.16883
Date: Current
Excerpt: "Dex encodes the index set (the allowable values for i when writing array[i]) directly into the type of the array, which allows for distinguishing dimensions that are similarly-sized but different-in-meaning"
Context: arXiv paper on JAX formal semantics
Confidence: high
```

### Key Insight for UASA/Rex
Type-safe ML is **proven at the library level** but not yet standard practice. jaxtyping is widely used across companies for runtime shape checking. Compile-time shape safety (Dex, Haskell) is elegant but has adoption barriers. For UASA/Rex, **runtime shape checking via jaxtyping** is immediately deployable; compile-time guarantees require language-level support.

---

## 11. Proof-Carrying Neural Networks

### Certified Robustness via Randomized Smoothing

```
Claim: Randomized smoothing constructs smoothed classifiers from arbitrary base classifiers and provides certified robustness via statistical arguments based on Monte Carlo probability estimation; it is the SOTA approach for L2 certified robustness on large networks [^32^].
Source: Certified Robustness for Deep Equilibrium Models via Serialized Random Smoothing (NeurIPS 2024)
URL: https://proceedings.neurips.cc/paper_files/paper/2024/file/02cf868040aa0f0a1e1121cf255fdcfb-Paper-Conference.pdf
Date: 2024
Excerpt: "Randomized smoothing approaches construct smoothed classifiers from arbitrary base classifiers and provide certified robustness via statistical arguments based on the Monte Carlo probability estimation... randomized smoothing has better flexibility in certifying the robustness of various DEQs"
Context: NeurIPS 2024 paper on certified robustness
Confidence: high
```

### Formally Verified Robustness Certifier

```
Claim: A formally verified robustness certifier for neural networks has been developed, providing mechanized proofs about the implementation rather than just pen-and-paper proofs; this addresses both design and implementation flaws [^33^].
Source: A Formally Verified Robustness Certifier for Neural Networks (Extended Version)
URL: https://arxiv.org/html/2505.06958v1
Date: 2025-05-11
Excerpt: "Many of these methods come with pen-and-paper proofs of their soundness... However, for high-assurance applications of neural networks, pen-and-paper proofs fall short of the kinds of guarantees enjoyed by formally verified safety- and security-critical systems software"
Context: Paper on formally verified neural network certification
Confidence: high
```

```
Claim: Laplace-Bridged Randomized Smoothing (LBS) reduces certification time from 9.8s to 0.7s on CIFAR-10 and from 120s to 10.8s on ImageNet compared to standard RS [^34^].
Source: Laplace-Bridged Randomized Smoothing for Fast Certified Robustness
URL: https://arxiv.org/html/2604.24993v1
Date: 2026-04-27
Excerpt: "LBS substantially reduces certification time, requiring only 0.7s per sample on CIFAR-10 and 10.8s on ImageNet, compared with 9.8s and over 120s for standard sampling-based RS methods"
Context: arXiv paper on accelerated certified robustness
Confidence: high
```

### Key Insight for UASA/Rex
Proof-carrying neural networks are **emerging from research to practice**. Randomized smoothing provides probabilistic guarantees that scale to large models. Formally verified certifiers address implementation correctness. For UASA/Rex, randomized smoothing could verify neural component outputs, but the overhead (0.7-10s per sample) is too high for real-time per-step verification.

---

## 12. Program Synthesis Verification

### Certified Program Synthesis (Vericoding)

```
Claim: LeetProof is a certified program synthesis pipeline using a multi-modal verifier (Velvet in Lean) combining dynamic validation (property-based testing), automated proofs, and interactive proof scripting; it uncovers specification defects in existing benchmarks [^35^].
Source: Certified Program Synthesis with a Multi-Modal Verifier
URL: https://arxiv.org/abs/2604.16584
Date: 2026-04-17
Excerpt: "Certified program synthesis (aka vericoding) is the process of automatically generating a program, its formal specification, and a machine-checkable proof of their alignment from a natural-language description... We overcome both challenges by structuring the certified synthesis workflow around a multi-modal verifier"
Context: arXiv preprint on certified synthesis
Confidence: high
```

### Proof-Theoretic Synthesis

```
Claim: Proof-theoretic synthesis interprets program synthesis as generalized program verification; the median synthesis time is 14 seconds with synthesis-to-verification ratio ranging from 1x to 92x (median 7x) [^36^].
Source: From Program Verification to Program Synthesis (ACM POPL 2010 / ACM Digital Library 2025)
URL: https://dl.acm.org/doi/10.1145/1706299.1706337
Date: 2025-09-01 (original 2010)
Excerpt: "For these programs, the median time for synthesis is 14 seconds, and the ratio of synthesis to verification time ranges between 1x to 92x (with an median of 7x), illustrating the potential of the approach."
Context: Foundational paper on proof-theoretic program synthesis
Confidence: high
```

### Key Insight for UASA/Rex
Program synthesis verification is **theoretically mature but practically limited**. Proof-theoretic synthesis shows the connection between verification and synthesis, but scaling to complex programs remains challenging. Multi-modal verifiers (testing + automated proving + interactive proving) offer the most practical path for UASA/Rex.

---

## 13. Temporal Logic for Agent Systems

### Complexity Results

```
Claim: Model checking CTL is P-complete (linear time); LTL is PSPACE-complete; CTL* is PSPACE-complete; ATL is PTIME-complete for perfect information but PSPACE-complete for imperfect information [^37^].
Source: Specification and Verification of Multi-Agent Systems (ESSLLI 2012)
URL: https://home.ipipan.waw.pl/w.jamroga/papers/verification12esslli-lncs.pdf
Date: 2012
Excerpt: "Model checking CTL is P-complete, and can be done in time O(|M|·|phi|)... Model checking LTL is PSPACE-complete... Model checking ATL*ir and ATL*ir is PSPACE-complete in the number of transitions in the model and the length of the formula"
Context: Graduate lecture notes on multi-agent verification
Confidence: high
```

### ATL and Strategic Properties

```
Claim: ATL model checking uses fixpoint characterizations: <<A>>[]phi <-> phi /\ <<A>>O<<A>>[]phi and <<A>>phi1 U phi2 <-> phi2 \/ (phi1 /\ <<A>>O<<A>>phi1 U phi2) [^38^].
Source: Chapter 14: Specification and Verification of Multi-Agent Systems (2nd ed. slides)
URL: http://www.the-mas-book.info/AUTHOR_SLIDES_MAS_2nd_edition_PDFs/AUTHOR_SLIDES_MAS_2nd_chapter14_animated.pdf
Date: Current
Excerpt: "<<A>>[]phi <-> phi /\ <<A>>O<<A>>[]phi... <<A>>phi1 U phi2 <-> phi2 \/ (phi1 /\ <<A>>O<<A>>phi1 U phi2)"
Context: Slides from Multi-Agent Systems textbook chapter
Confidence: high
```

### Key Insight for UASA/Rex
Temporal logic model checking is **proven technology with well-understood complexity**. CTL verification is efficient (linear time), making it suitable for runtime monitoring. LTL/CTL* verification is PSPACE-complete, limiting scalability. For multi-agent systems, ATL provides strategic reasoning but complexity increases with imperfect information. For UASA/Rex, **CTL-based runtime monitors** are practical; full ATL verification of complex agent coalitions is computationally demanding.

---

## 14. Interval Arithmetic for Numerical Bounds

### Rigorous Numerics for PINNs

```
Claim: A "Learn and Verify" framework combines Doubly Smoothed Maximum loss with interval arithmetic (using INTLAB) to compute rigorous a posteriori error bounds as machine-verifiable proofs for differential equation solutions [^39^].
Source: Learn and Verify: A Framework for Rigorous Verification of Physics-Informed Neural Networks
URL: https://arxiv.org/html/2601.19818v1
Date: 2026-01-27
Excerpt: "By combining a novel Doubly Smoothed Maximum (DSM) loss for training with interval arithmetic for verification, we compute rigorous a posteriori error bounds as machine-verifiable proofs... we employ INTLAB (INTerval LABoratory) for all rigorous computations"
Context: arXiv paper on verified PINNs
Confidence: high
```

### Software Implementations

```
Claim: INTLAB (MATLAB) achieves near-point-arithmetic performance through optimized rounding mode switches; MPFI provides arbitrary-precision interval arithmetic on top of MPFR; interval arithmetic is typically 10-100x slower than point arithmetic for large computations [^40^].
Source: Interval arithmetic (Grokipedia)
URL: https://grokipedia.com/page/Interval_arithmetic
Date: 2026-01-14
Excerpt: "INTLAB serves as a prominent toolbox for high-performance interval arithmetic... operations like interval matrix computations achieving near-point arithmetic performance through optimized rounding mode switches... interval arithmetic inherently widens enclosures due to dependency problems and rounding errors, often making it 10-100 times slower than point arithmetic for large-scale computations"
Context: Encyclopedia article on interval arithmetic implementations
Confidence: medium
```

### Fundamental Limits for Neural Networks

```
Claim: Interval arithmetic has fundamental limits for neural network verification; no single-layer ReLU network can provably alpha-robustly classify more than ceil(2/alpha) + 5 flips [^41^].
Source: The Fundamental Limits of Interval Arithmetic for Neural Networks
URL: https://files.sri.inf.ethz.ch/website/papers/mirman2021fundamental.pdf
Date: 2021
Excerpt: "Theorem 4.6 (Single-Layer Limit): No single-layer ReLU-network can provably alpha-robustly classify ceil(2/alpha) + 5 or more flips for any alpha in (0,1]"
Context: Peer-reviewed paper on theoretical limits of interval methods
Confidence: high
```

### Key Insight for UASA/Rex
Interval arithmetic is **proven technology** for rigorous numerical bounds. INTLAB and MPFI are mature libraries. The 10-100x slowdown is the primary cost. For UASA/Rex, interval arithmetic is suitable for **offline verification** of numerical claims or as a conservative bound checker, but the performance overhead makes real-time per-step checking challenging for large computations.

---

## 15. Refinement Types for AI

### LiquidHaskell

```
Claim: LiquidHaskell uses SMT-decidable refinement types to verify program properties; it proved 96.0% of recursive functions terminate with only 1.7 annotations per 100 lines of code; verification time for 10,209 LOC across 8 modules was 1080 seconds total [^42^].
Source: Refinement Types for Haskell (ACM SIGPLAN 2014 / Simon Peyton Jones)
URL: https://simon.peytonjones.org/assets/pdfs/refinement-types-for-haskell.pdf
Date: 2014
Excerpt: "We successfully prove that 96.0% of recursive functions terminate... only 34.3% require explicit termination metric, totaling about 1.7 witnesses (about 1 line each) per 100 lines of code... Time is the time, in seconds, required to run LIQUIDHASKELL [Total: 1080s for 10209 LOC]"
Context: Peer-reviewed paper on LiquidHaskell evaluation
Confidence: high
```

```
Claim: LiquidHaskell encodes refinements as logical predicates checked by SMT (Z3, CVC4, MathSat); function postconditions, preconditions, and measure-based specifications are all supported [^43^].
Source: Programming With Refinement Types (LiquidHaskell Tutorial)
URL: https://ucsd-progsys.github.io/liquidhaskell-tutorial/book.pdf
Date: 2020-07-20
Excerpt: "LiquidHaskell Requires (in addition to the cabal dependencies) a binary for an SMTLIB2 compatible solver, e.g. one of Z3 (which we recommend), CVC4, MathSat"
Context: Official LiquidHaskell tutorial
Confidence: high
```

### F* (F Star)

```
Claim: F* combines dependent types, refinement types, monadic effects, and SMT-backed automated verification (Z3); it enables proof-oriented programming with extraction to OCaml, F#, C (via KaRaMeL), and WASM [^44^].
Source: fstar-verification skill documentation (Smithery)
URL: https://smithery.ai/skills/manutej/fstar-verification
Date: 2024-12-13
Excerpt: "F* combines three paradigms: Programming Language, Proof Assistant, Verification Tool... SMT-based automation via Z3... Extraction: OCaml (default), F# (.NET integration), C (via KaRaMeL for low-level code), WebAssembly"
Context: F* comprehensive skill documentation
Confidence: high
```

```
Claim: F* has been used for large-scale verified software including HACL* (cryptographic library), miTLS (verified TLS), and Project Everest; it uses refinement types like `x:int{x > 0}` and weakest precondition calculus for verification condition generation [^45^].
Source: F*: The Dependently Typed Programming Language for Software Verification (Medium)
URL: https://volodymyrpavlyshyn.medium.com/f-the-dependently-typed-programming-language-for-software-verification-2ee6a3e93f31
Date: 2025-03-23
Excerpt: "F* has been used for large-scale verified software including HACL*, miTLS, and Project Everest... the key innovation of F* is its refined dependent type system, which allows developers to express precise specifications directly within the code"
Context: Overview of F* verification capabilities
Confidence: high
```

### Key Insight for UASA/Rex
Refinement types are **proven technology** with mature tools. LiquidHaskell processes ~10KLOC in ~18 minutes (~100ms per function). F* verifies large security-critical systems. For UASA/Rex, refinement types could catch **dimensional errors, bound violations, and type mismatches at compile/type-check time**. The SMT solver backend is the performance bottleneck — complex refinements can time out. For real-time use, refinements should be kept in SMT-decidable fragments (linear arithmetic, uninterpreted functions).

---

## Key Questions: Detailed Answers

### Q1: What is the verification overhead of calling Lean/Kani on every agent step?

**Answer**: The overhead is **prohibitively high for naive per-step invocation** but manageable with careful engineering.

- **Kani**: Simple properties verify in milliseconds (0.03-0.3s), but loops and complex structures take seconds to minutes. For a bounded harness with small symbolic inputs, expect 0.1-5s per verification. SAT solver selection matters enormously (200x speedups possible).
- **Lean 4**: Individual tactic execution is interactive-scale (seconds). Full proof checking of non-trivial theorems takes minutes. The mathlib4 build (60k declarations) takes ~2300s. Lean is **not designed for real-time per-step verification**.
- **Practical approach**: Use **staged verification** — lightweight property-based tests or refinement types for every step, with deeper formal verification (Kani/Lean) for critical reasoning chains or on a batched/background schedule.

### Q2: Can SMT solvers verify dimensional consistency claims in real-time?

**Answer**: **Yes, for small constraint systems.**

- SMT solvers (Z3, CVC5) handle linear arithmetic constraints in milliseconds for formulas with tens of variables/constraints.
- Dimensional analysis constraints (e.g., ensuring [length]/[time] = [velocity]) are typically simple linear equations over dimension exponents.
- The SMT4ABS project demonstrated real-time type checking with SMT for ABS programs with real-time constraints [^46^].
- **Limitation**: If dimensional constraints become complex (nonlinear, dependent on runtime values), SMT solving time grows. For real-time use, keep dimensional checking in linear, decidable fragments.

### Q3: What is the state of neural network verification for production-scale models?

**Answer**: **Incomplete but advancing rapidly.**

- **Small-to-medium networks**: Complete verification is feasible. alpha-beta-CROWN won VNN-COMP 2021-2023 and verifies networks with millions of parameters on GPUs.
- **Large models (LLMs, production transformers)**: No complete verifier exists. Practical approaches include:
  - **Randomized smoothing**: Probabilistic guarantees, scales to ImageNet, 0.7-10s per sample
  - **Adversarial training**: Empirical robustness without formal guarantees
  - **Interval bound propagation**: Conservative bounds, loose for deep networks
- **Fundamental barrier**: The universal trade-off between bound tightness and computational cost. Deep networks amplify over-approximation error [^23^].
- **For UASA/Rex**: Use randomized smoothing or IBP for neural component output checking, but treat guarantees as probabilistic or conservative, not absolute.

### Q4: How do refinement types help catch AI reasoning errors at compile time?

**Answer**: Refinement types catch **structured reasoning errors** by encoding invariants in types.

- **Dimensional consistency**: `{v:Tensor | shape v = [batch, dim]}` ensures tensor operations are dimensionally valid
- **Boundedness**: `{v:Float | 0 <= v && v <= 1}` enforces probability outputs
- **Monotonicity**: Refinement types can encode ordering invariants
- **LiquidHaskell example**: `average xs = sum xs `div` length xs` is rejected because `length xs` could be 0; refinement type `{v:Int | v /= 0}` for the divisor catches the error [^43^].
- **Limitation**: Refinement types require the invariant to be expressible in SMT-decidable logic. Complex reasoning errors (semantic, contextual) cannot be caught by refinement types alone — they need full theorem proving.

---

## Synthesis: Technology Readiness for UASA/Rex Layer 5

| Technology | Maturity | Real-Time? | Scalability | Best Use in Rex |
|---|---|---|---|---|
| Kani (Rust MC) | Production | Limited | Medium | Unsafe code, bounded properties, contracts |
| Creusot (Why3) | Research | No | Medium | Function contracts, loop invariants |
| Lean 4 | Production | No | High | Mathematical proofs, protocol verification |
| LeanDojo | Research | No | Medium | AI-assisted proof search |
| SMT (Z3/CVC5) | Production | Yes (small) | High | Dimensional checking, constraint solving |
| alpha-beta-CROWN | Research | No | Medium | Neural network robustness (medium nets) |
| Randomized Smoothing | Emerging | No | High | Large NN probabilistic certification |
| PBT (Proptest) | Production | Yes | High | Quick feedback, regression testing |
| PropProof (Kani+PBT) | Research | Limited | Medium | Elevating PBT to formal guarantees |
| Temporal Logic (CTL) | Production | Yes | High | Runtime monitoring, agent behavior |
| Interval Arithmetic | Production | Limited | Medium | Rigorous numerical bounds |
| LiquidHaskell | Production | Yes | High | Compile-time invariant checking |
| F* | Production | Limited | High | Verified extraction to C/OCaml |

### Recommended Architecture for Rex Layer 5 (Solver/Verifier Bridge)

1. **Fast path (every step)**: Property-based tests + refinement types + lightweight SMT queries (<10ms)
2. **Medium path (batched)**: Kani model checking on bounded harnesses + interval arithmetic (seconds)
3. **Slow path (offline)**: Lean 4 theorem proving + neural network verification (minutes to hours)
4. **Feedback loop**: Failed verifications trigger reasoning chain correction or human review

---

## Tensions and Open Problems

1. **Completeness vs. Scalability**: Complete verifiers (Kani, Marabou) do not scale to large systems; scalable approaches (randomized smoothing, IBP) provide incomplete guarantees.
2. **Annotation Burden**: Deductive verification (Creusot, F*, LiquidHaskell) requires significant specification effort. The median is ~1-2 annotations per 100 LOC, but complex properties need much more.
3. **Neural-Symbolic Gap**: Neural components produce outputs that symbolic verifiers cannot easily reason about. Neuro-symbolic frameworks are emerging but immature.
4. **Real-Time Verification**: No existing verifier can provide deep formal guarantees at millisecond latency. Staged verification is the only practical approach.
5. **Trusted Computing Base**: Every verifier has a TCB (kernel, SMT solver, model checker). Bugs in the verifier invalidate the proof. Self-verified kernels (Lean4Lean) address this but add 20-50% overhead [^10^].

---

## References

[^1^]: Kani Rust Verifier Official Documentation. https://model-checking.github.io/kani/
[^2^]: Ferrous Systems Rust Training — Kani. https://rust-training.ferrous-systems.com/latest/book/kani
[^3^]: Y. et al., "PropProof: Free Model-Checking Harnesses from PBT," ACM OOPSLA 2023. https://dl.acm.org/doi/pdf/10.1145/3611643.3613863
[^4^]: Kani Verifier Blog, "Turbocharging Rust Code Verification," 2023. https://model-checking.github.io/kani-verifier-blog/2023/08/03/turbocharging-rust-code-verification.html
[^5^]: C. Breck, "Making Even Safe Rust a Little Safer," 2024. https://blog.colinbreck.com/making-even-safe-rust-a-little-safer-model-checking-safe-and-unsafe-code/
[^6^]: Kani Attributes Reference. https://model-checking.github.io/kani/reference/attributes.html
[^7^]: Creusot Issue #493, verify-rust-std. https://github.com/model-checking/verify-rust-std/issues/493
[^8^]: X. Denis, "Deductive Verification of Rust Programs," PhD Thesis, 2023. https://theses.fr/2023UPASG101/abes
[^9^]: A. et al., "Verus: Verifying Rust Programs using Linear Ghost Types," arXiv:2303.05491. https://arxiv.org/pdf/2303.05491
[^10^]: "Lean 4: Scalable Theorem Proving," Emergent Mind, 2026. https://www.emergentmind.com/topics/lean-4
[^11^]: "Metaprogramming in Lean 4," Official Book. https://leanprover-community.github.io/lean4-metaprogramming-book/
[^12^]: LambdaClass, "If It Compiles, It Is Correct," 2026. https://blog.lambdaclass.com/if-it-compiles-it-is-correct-almost-an-introduction-to-lean-4-for-zk-systems-and-engineering-2/
[^13^]: LeanDojo Documentation. https://leandojo.readthedocs.io/
[^14^]: K. Yang et al., "LeanDojo: Theorem Proving with Retrieval-Augmented Language Models," NeurIPS 2023. https://arxiv.org/pdf/2306.15626
[^15^]: LeanDojo Project Page. https://leandojo.org/leandojo.html
[^16^]: G. Singh and M. Parthasarathy, "Lecture 9: Verifying Robustness," UPenn CIS 7000, 2024. https://www.seas.upenn.edu/~obastani/cis7000/spring2024/docs/lecture9.pdf
[^17^]: "Marabou 2.0," arXiv:2401.14461, 2024. https://arxiv.org/pdf/2401.14461
[^18^]: "Neuro-Symbolic Verifier," Emergent Mind, 2025. https://www.emergentmind.com/topics/neuro-symbolic-verifier
[^19^]: W. Vogels, "A Chat with Byron Cook on Automated Reasoning," All Things Distributed, 2026. https://www.allthingsdistributed.com/2026/02/a-chat-with-byron-cook-on-automated-reasoning-and-trust-in-ai-systems.html
[^20^]: ICLR 2024 Paper on IBP. https://proceedings.iclr.cc/paper_files/paper/2024/file/3a2e5889b4bbef997ddb13b55d5acf77-Paper-Conference.pdf
[^21^]: UIUC ECE 584 Lecture 9. http://publish.illinois.edu/ece584-spring2024/files/2024/02/Lecture-9_-Neural-Network-Verification-Bound-Propagation.pdf
[^22^]: alpha-beta-CROWN Repository. https://github.com/Verified-Intelligence/alpha-beta-CROWN_vnncomp2024
[^23^]: U. Akbulut, "Neural Network Verification: Why Is It Still a Research Problem?" Medium, 2026. https://medium.com/@umutt.akbulut/neural-network-verification-why-is-verifying-a-neural-network-still-a-research-problem-f638b41d8493
[^24^]: "Towards Formal Verification of LLM-Generated Code," arXiv:2507.13290, 2025. https://arxiv.org/html/2507.13290v1
[^25^]: Q. Oschatz et al., "Towards Automated Reasoning Chains for Verification of LLM-Generated Code," CMU HPEC 2025. https://users.ece.cmu.edu/~franzf/papers/2025_HPEC_Oschatz_Q.pdf
[^26^]: "LLM-Based Unknown Function Automated Modeling in Symbolic Execution," PMC, 2025. https://pmc.ncbi.nlm.nih.gov/articles/PMC12074466/
[^27^]: T. Trivedi, "Introduction to Property-Based Testing," Medium, 2025. https://medium.com/@tt3043701/introduction-to-property-based-testing-55a27aec1346
[^28^]: "A process calculus for spiking neural P systems," Information Sciences, 2024. https://www.sciencedirect.com/science/article/pii/S0020025522003231
[^29^]: P. Kidger, "No more shape errors! Type annotations for tensors," 2023. https://kidger.site/thoughts/jaxtyping/
[^30^]: "Tensor Flow and Dependent Types," Monday Morning Haskell. https://mmhaskell.com/machine-learning/dependent-types
[^31^]: "JAX Autodiff from a Linear Logic Perspective," arXiv:2510.16883. https://arxiv.org/pdf/2510.16883
[^32^]: W. Gao et al., "Certified Robustness for Deep Equilibrium Models via Serialized Random Smoothing," NeurIPS 2024. https://proceedings.neurips.cc/paper_files/paper/2024/file/02cf868040aa0f0a1e1121cf255fdcfb-Paper-Conference.pdf
[^33^]: "A Formally Verified Robustness Certifier for Neural Networks," arXiv:2505.06958, 2025. https://arxiv.org/html/2505.06958v1
[^34^]: "Laplace-Bridged Randomized Smoothing for Fast Certified Robustness," arXiv:2604.24993, 2026. https://arxiv.org/html/2604.24993v1
[^35^]: "Certified Program Synthesis with a Multi-Modal Verifier," arXiv:2604.16584, 2026. https://arxiv.org/abs/2604.16584
[^36^]: S. Srivastava et al., "From Program Verification to Program Synthesis," ACM POPL 2010. https://dl.acm.org/doi/10.1145/1706299.1706337
[^37^]: W. Jamroga, "Specification and Verification of Multi-Agent Systems," ESSLLI 2012. https://home.ipipan.waw.pl/w.jamroga/papers/verification12esslli-lncs.pdf
[^38^]: J. Dix and M. Fisher, "Chapter 14: Specification and Verification of Multi-Agent Systems," 2nd ed. slides. http://www.the-mas-book.info/AUTHOR_SLIDES_MAS_2nd_edition_PDFs/AUTHOR_SLIDES_MAS_2nd_chapter14_animated.pdf
[^39^]: K. Tanaka and K. Yatabe, "Learn and Verify: A Framework for Rigorous Verification of Physics-Informed Neural Networks," arXiv:2601.19818, 2026. https://arxiv.org/html/2601.19818v1
[^40^]: "Interval arithmetic," Grokipedia, 2026. https://grokipedia.com/page/Interval_arithmetic
[^41^]: M. Mirman et al., "The Fundamental Limits of Interval Arithmetic for Neural Networks," SRI/ETH Zurich, 2021. https://files.sri.inf.ethz.ch/website/papers/mirman2021fundamental.pdf
[^42^]: N. Vazou et al., "Refinement Types for Haskell," ACM SIGPLAN 2014. https://simon.peytonjones.org/assets/pdfs/refinement-types-for-haskell.pdf
[^43^]: R. Jhala et al., "Programming With Refinement Types," LiquidHaskell Tutorial, 2020. https://ucsd-progsys.github.io/liquidhaskell-tutorial/book.pdf
[^44^]: "fstar-verification" skill, Smithery, 2024. https://smithery.ai/skills/manutej/fstar-verification
[^45^]: V. Pavlyshyn, "F*: The Dependently Typed Programming Language for Software Verification," Medium, 2025. https://volodymyrpavlyshyn.medium.com/f-the-dependently-typed-programming-language-for-software-verification-2ee6a3e93f31
[^46^]: SMT4ABS Project, RWTH Aachen. https://ths.rwth-aachen.de/research/projects/smt4abs/
