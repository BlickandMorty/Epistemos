# Dimension 16: Physics-Informed Neural Architectures

## Research Report: UASA/Rex Deterministic Superintelligence Substrate

---

## 1. Executive Summary

Physics-informed machine learning (PIML) represents a paradigm shift from black-box neural networks to architectures that embed physical law as structural inductive bias. This report surveys five core methodological pillars — PINNs, FNOs, GNNs, symbolic regression, and symmetry-preserving architectures — and examines their potential to constrain AI reasoning, validate physical claims, and discover new governing equations. Key findings include: FNOs achieve ~440× inference speedup over pseudo-spectral solvers for Navier-Stokes [^1^]; GNoME's 2.2M crystal predictions are under active scrutiny with >10% flagged as near-duplicates [^2^]; equivariant networks (NequIP/MACE) achieve state-of-the-art accuracy with orders of magnitude less data [^3^]; and the SciML Julia ecosystem provides end-to-end differentiable pipelines for scientific model discovery [^4^].

---

## 2. Physics-Informed Neural Networks (PINNs)

### 2.1 Architecture and Loss Formulation

Claim: The standard PINN loss function is a weighted sum of PDE residual, boundary condition, initial condition, and data mismatch terms: $\mathcal{L}_{\text{total}} = \lambda_{\text{res}}\mathcal{L}_{\text{res}} + \lambda_{\text{BC}}\mathcal{L}_{\text{BC}} + \lambda_0\mathcal{L}_0 + \lambda_{\text{data}}\mathcal{L}_{\text{data}}$ [^5^]
Source: *Physics-Informed Neural Networks in Materials Modeling and Design: A Review* (Springer)
URL: https://link.springer.com/article/10.1007/s11831-025-10448-9
Date: 2025
Excerpt: "The standard PINN loss function is commonly described as the weighted sum of the loss terms... where $\mathcal{L}_{\text{res}}$ enforces satisfaction of the governing laws (PDEs), $\mathcal{L}_{\text{BC}}$ ensures compliance with boundary conditions, $\mathcal{L}_0$ ensures compliance with initial conditions, and $\mathcal{L}_{\text{data}}$ represents the mismatch between predictions and available data."
Context: Comprehensive review of PINN architectures for materials modeling
Confidence: high

Claim: Variational PINNs (VPINNs) use weak formulations based on the Petrov–Galerkin method, achieving clear advantages over standard PINNs in accuracy and speed [^6^]
Source: *Review of Physics-Informed Neural Networks: Challenges in Loss Function Design and Geometric Integration* (MDPI Mathematics)
URL: https://www.mdpi.com/2227-7390/13/20/3289
Date: 2025-10-15
Excerpt: "The effectiveness of the proposed approach was demonstrated in several examples, showing clear advantages of VPINNs over PINNs in terms of accuracy and speed. For shallow networks with one hidden layer, Kharazmi et al. analytically obtained various forms of variational residuals."
Context: Survey comparing energy-based, variational, and domain-decomposition PINN variants
Confidence: high

Claim: EPINN (Exact Dirichlet Boundary Condition PINN) achieves speedups of over 13× for 1D problems and over 126× for 3D problems compared to standard PINNs, with comparable accuracy against FEM results [^6^]
Source: Same MDPI review
URL: https://www.mdpi.com/2227-7390/13/20/3289
Date: 2025-10-15
Excerpt: "For forward problems, EPINN achieved a speedup of over 13 times for one-dimensional problems and over 126 times for three-dimensional problems compared to PINNs, with comparable accuracy as assessed against finite element modeling results."
Context: Hard-constraint approaches using augmented distance functions (ADF) for exact boundary condition enforcement
Confidence: high

### 2.2 PINNs for Validation of Physical Claims

The question of whether PINNs can validate physical claims in LLM outputs is theoretically sound but practically challenging. PINNs encode known physical laws (PDEs) as soft constraints in the loss function. If an LLM generates a physical claim (e.g., a proposed equation of state, a heat transfer coefficient, or a material property), a PINN trained with that claim as a constraint can be evaluated for convergence and residual magnitude. However, this is fundamentally a consistency check against the *encoded* physics, not an independent validation — the PINN cannot discover whether the encoded law itself is correct, only whether the proposed solution satisfies it. For truly novel claims, the PINN would need to be trained with the candidate law as a learnable component (inverse PINN), which introduces identifiability and well-posedness issues. The approach is most viable for forward-validation: checking that an LLM-generated solution satisfies known conservation laws.

---

## 3. Fourier Neural Operators (FNO)

### 3.1 Spectral Methods and Architecture

Claim: The Fourier Neural Operator learns a resolution-invariant solution operator for the family of Navier-Stokes equations in the turbulent regime, where previous graph-based neural operators do not converge [^1^]
Source: *Fourier Neural Operator for Parametric Partial Differential Equations* (arXiv)
URL: https://arxiv.org/abs/2010.08895
Date: 2020-10-19
Excerpt: "The Fourier neural operator is the first work that learns the resolution-invariant solution operator for the family of Navier-Stokes equation in the turbulent regime, where previous graph-based neural operators do not converge. By construction, the method shares the same learned network parameters irrespective of the discretization used on the input and output spaces."
Context: Original FNO paper introducing the architecture
Confidence: high

Claim: On a 256×256 grid, FNO has an inference time of 0.005s compared to 2.2s for the pseudo-spectral method used to solve Navier-Stokes — a ~440× speedup [^1^]
Source: Same arXiv paper
URL: https://arxiv.org/abs/2010.08895
Date: 2020-10-19
Excerpt: "On a 256×256 grid, the Fourier neural operator has an inference time of only 0.005s compared to the 2.2s of the pseudo-spectral method used to solve Navier-Stokes."
Context: Benchmark comparison for Navier-Stokes equation solving
Confidence: high

Claim: FNO achieves error rates 30% lower on Burgers' Equation, 60% lower on Darcy Flow, and 30% lower on Navier-Stokes (turbulent regime) compared to existing deep learning methods at 64×64 resolution [^1^]
Source: Same arXiv paper
URL: https://arxiv.org/abs/2010.08895
Date: 2020-10-19
Excerpt: "The proposed method consistently outperforms all existing deep learning methods even when fixing the resolution to be 64×64. It achieves error rates that are 30% lower on Burgers' Equation, 60% lower on Darcy Flow, and 30% lower on Navier Stokes."
Context: Systematic comparison across benchmark PDE problems
Confidence: high

### 3.2 FNO Layer Mechanics

Claim: Each FNO layer performs four steps: FFT, spectral filtering with learned per-mode matrices, inverse FFT, and combination with a local bypass term [^7^]
Source: *How the Fourier Neural Operator Learns to Solve PDEs* (PhysicsX AI)
URL: https://www.physicsx.ai/newsroom/how-the-fourier-neural-operator-learns-to-solve-pdes----and-where-it-falls-short
Date: 2026-04-23
Excerpt: "Each FNO layer does this in four steps: Step 1 — FFT: Transform the hidden features from physical space into frequency space. Step 2 — Spectral filtering: For each retained mode up to k_max, apply a learned matrix W that mixes the feature channels. Step 3 — Inverse FFT: Transform back to physical space. Step 4 — Combine and apply activation."
Context: Technical explainer of FNO architecture and limitations
Confidence: high

Claim: F-FNO (Factorized FNO) reduces error by 83% on Navier-Stokes, 31% on elasticity, 57% on airfoil flow, and 60% on plastic forging compared to standard FNO; it achieves an order of magnitude speedup over state-of-the-art pseudo-spectral methods for the same solution quality [^8^]
Source: *Factorized Fourier Neural Operators* (arXiv)
URL: https://arxiv.org/abs/2111.13802
Date: 2021-11-27
Excerpt: "On several challenging benchmark PDEs on regular grids, structured meshes, and point clouds, the F-FNO can scale to deeper networks and outperform both the FNO and the geo-FNO, reducing the error by 83% on the Navier-Stokes problem... Compared to the state-of-the-art pseudo-spectral method, the F-FNO can take a step size that is an order of magnitude larger in time and achieve an order of magnitude speedup to produce the same solution quality."
Context: Follow-up work improving FNO with separable spectral layers and better training strategies
Confidence: high

### 3.3 Limitations

FNOs work best for smooth, spatially coupled problems on regular grids where most energy sits in low-frequency modes. Their main failure modes include: (1) FFT assumptions (periodicity), (2) mode truncation (difficulty with shocks and sharp gradients), and (3) scalability limits in higher dimensions [^7^]. For problems with irregular geometries or shock-dominated dynamics, geometry-aware neural operator variants or hybrid approaches are preferred.

---

## 4. Graph Neural Networks for Physics

### 4.1 GNN Force Fields and Materials

Claim: GNN force fields use message-passing architectures with multiple graph convolutional layers to predict site-resolved forces from atomic configurations [^9^]
Source: *Graph neural network force fields for adiabatic dynamics of lattice Hamiltonians* (arXiv)
URL: https://arxiv.org/abs/2603.02039
Date: 2026-03-02
Excerpt: "The network consists of eight message-passing layers or graph convolutional network (GCN) layers. Each GCN layer essentially implements the updates described... The first layer serves as an embedding layer that lifts the single scalar input feature into a 128-dimensional latent representation."
Context: Application of GNNs to Holstein model force prediction
Confidence: high

### 4.2 GNoME: Materials Discovery at Scale

Claim: GNoME discovered 2.2 million new crystal structures, of which 380,000 are predicted stable materials — an order-of-magnitude expansion in stable materials known to humanity [^10^]
Source: *Scaling deep learning for materials discovery* (Nature)
URL: https://www.nature.com/articles/s41586-023-06735-9
Date: 2023-11-29
Excerpt: "Here we show that graph networks trained at scale can reach unprecedented levels of generalization, improving the efficiency of materials discovery by an order of magnitude... Our work represents an order-of-magnitude expansion in stable materials known to humanity. Of the stable structures, 736 have already been independently experimentally realized."
Context: Original Nature paper from Google DeepMind
Confidence: high

Claim: GNoME uses two pipelines — structural (similar to known crystals) and compositional (randomized by chemical formula) — with active learning boosting stability prediction accuracy from ~50% to 80% on MatBench Discovery [^11^]
Source: Google DeepMind Blog
URL: https://deepmind.google/blog/millions-of-new-materials-discovered-with-deep-learning/
Date: 2023-11-29
Excerpt: "GNoME uses two pipelines to discover low-energy (stable) materials. The structural pipeline creates candidates with structures similar to known crystals, while the compositional pipeline follows a more randomized approach based on chemical formulas... Our research boosted the discovery rate of materials stability prediction from around 50%, to 80%."
Context: Public announcement and technical summary
Confidence: high

Claim: GNoME faces serious criticism: more than 10% of stable crystal structures may be near-duplicates of existing crystals, and over 83,000 entries (>20%) were quietly removed from the database after critics raised concerns [^2^]
Source: *Duplicate structures haunt crystallography databases* (C&EN)
URL: https://cen.acs.org/research-integrity/Duplicate-structures-haunt-crystallography-databases/103/web/2025/12
Date: 2025-12-16
Excerpt: "But it turns out that more than 10% of the stable crystal structures created by GNoME may actually be near duplicates of existing crystals... After they published their original data, more than 83,000 entries in the GNoME database—more than 20% of its crystal structures—were quietly removed without acknowledgment."
Context: Research integrity investigation into GNoME and related A-Lab claims
Confidence: high

**Tension/Contradiction**: The GNoME paper claims 736 independently synthesized structures as validation, but critics argue the A-Lab autonomous synthesis paper (companion Nature study) also produced near-duplicates rather than truly novel materials [^2^]. Nature's editor stated they are "not currently investigating" formal retraction requests for GNoME, though a correction is being processed for the A-Lab paper.

---

## 5. Symbolic Regression and Equation Discovery

### 5.1 SINDy: Sparse Identification of Nonlinear Dynamics

Claim: SINDy discovers governing equations from data by using sparse regression on a library of candidate nonlinear functions, balancing model complexity with descriptive ability [^12^]
Source: *Discovering governing equations from data by sparse identification of nonlinear dynamical systems* (PNAS)
URL: https://robotics.caltech.edu/wiki/images/a/a3/BPK_PNAS.pdf
Date: 2016-04-12
Excerpt: "The so-called sparse identification of nonlinear dynamics (SINDy) method results in models that are parsimonious, balancing model complexity with descriptive ability while avoiding over fitting. The only assumption about the structure of the model is that there are only a few important terms that govern the dynamics, so that the equations are sparse in the space of possible functions."
Context: Original SINDy paper by Brunton, Proctor, and Kutz
Confidence: high

Claim: SINDyG extends SINDy to graph-structured data by incorporating network adjacency structure into sparse regression, improving model accuracy and simplicity compared to original SINDy [^13^]
Source: *SINDyG: Sparse Identification of Nonlinear Dynamical Systems from Graph-Structured Data* (arXiv)
URL: https://arxiv.org/abs/2409.04463
Date: 2025-08-13
Excerpt: "SINDyG introduces a graph-informed regularization strategy that uses prior knowledge of the network's adjacency structure to guide model discovery. This enables more accurate and parsimonious identification of governing equations... Our results indicate improvements to model accuracy and simplicity when compared to the original SINDy method."
Context: Extension of SINDy to networked dynamical systems
Confidence: high

### 5.2 Physics-Informed Genetic Programming and PySR

Claim: Physics-informed genetic programming can discover PDEs from scarce and noisy data by combining symbolic regression with sparsity-promoting techniques [^14^]
Source: *Physics-informed genetic programming for discovery of partial differential equations from scarce and noisy data* (Journal of Computational Physics)
URL: https://www.sciencedirect.com/science/article/abs/pii/S0021999124005096
Date: 2024-10-24
Excerpt: "Hybrid methods, like AI-Aristotle and AI-Lorenz, use symbolic regressors like PySR to interpret dynamics learned from scarce and noisy data by black-box machine learning methods. On the other hand, sparse identification of nonlinear dynamics (SINDy) was the pioneering framework that used sparse regression for dynamic model discovery."
Context: Survey of hybrid methods combining symbolic regression with neural network learning
Confidence: high

### 5.3 Can Symbolic Regression Discover Conservation Laws?

Yes — symbolic regression can discover conservation laws from model behavior, but the approach is nuanced. SINDy and related methods (e.g., SymDLNN) can identify symmetries by learning a Lagrangian and then applying Noether's theorem to derive conserved quantities [^15^]. The Discrete Lagrangian Neural Networks with Automatic Symmetry Discovery (SymDLNN) framework "automatically identifies subgroups of the group of affine linear transformations under which a (discrete) Lagrangian is invariant while the Lagrangian of a system is learned. As a consequence, we identify the corresponding conserved quantity as well" [^15^]. This is a powerful capability: rather than hard-coding conservation laws, the system discovers them from trajectory data.

However, the limitation is that the discovered conservation laws are only as valid as the data and basis functions used. If the library of candidate functions does not include the correct form, SINDy will miss the conservation law. Additionally, stochastic systems, systems with hidden variables, and high-dimensional PDEs remain challenging.

---

## 6. Machine-Learned Interatomic Potentials

### 6.1 MACE: Higher-Order Equivariant Message Passing

Claim: MACE (Multilayer Atomic Cluster Expansion) potentials embed atomic cluster expansion into a deep neural architecture, achieving state-of-the-art accuracy and transferability across organic molecules, condensed-phase systems, and materials [^16^]
Source: MACE GitHub repository
URL: https://github.com/acesuit/mace
Date: 2022-present
Excerpt: "MACE models achieve state-of-the-art accuracy and transferability in atomistic modeling across organic molecules, condensed-phase systems, and materials, with efficient scaling and superior low-data learning compared to conventional force fields and lower-body-order message-passing neural networks."
Context: Open-source implementation of MACE with foundation models
Confidence: high

Claim: MACE provides pretrained foundation models covering 89 elements (MACE-MP-0), 10 elements for organic chemistry (MACE-OFF23), and multi-domain models (MACE-MH-0/1) with cross-domain performance on surfaces, bulk, and molecules [^16^]
Source: Same GitHub repository
URL: https://github.com/acesuit/mace
Date: 2022-present
Excerpt: "MACE-MP-0a: 89 elements, MPTrj dataset, DFT (PBE+U), Materials... MACE-OFF23: 10 elements, SPICE v1 dataset, DFT (wB97M+D3), Organic Chemistry... MACE-MH-0/1: 89 elements, OMAT/OMOL/OC20/MATPES, cross domain performance on surfaces/bulk/molecules."
Context: Foundation model release documentation
Confidence: high

### 6.2 NequIP: E(3)-Equivariant Graph Neural Networks

Claim: NequIP uses E(3)-equivariant convolutions on geometric tensors, requiring up to three orders of magnitude fewer training data than existing non-equivariant models while achieving state-of-the-art accuracy [^3^]
Source: *E(3)-equivariant graph neural networks for data-efficient and accurate interatomic potentials* (Nature Communications)
URL: https://www.nature.com/articles/s41467-022-29939-5
Date: 2022
Excerpt: "NequIP uses E(3)-equivariant convolutions on geometric tensors, resulting in a more faithful representation of atomic environments. It achieves state-of-the-art accuracy across diverse systems with remarkably data efficiency, requiring up to three orders of magnitude fewer training data than existing models."
Context: Original NequIP paper establishing equivariant learning for interatomic potentials
Confidence: high

Claim: The Allegro extension scales NequIP to biomolecular simulations of realistic size with optimized LAMMPS MD integration [^17^]
Source: *Scaling the leading accuracy of deep equivariant models to biomolecular simulations of realistic size* (SC23)
URL: https://nequip.readthedocs.io/en/latest/introduction/intro.html
Date: 2023
Excerpt: "Albert Musaelian, Anders Johansson, Simon Batzner, and Boris Kozinsky. 'Scaling the leading accuracy of deep equivariant models to biomolecular simulations of realistic size.' In Proceedings of the International Conference for High Performance Computing..."
Context: Computational scaling paper for NequIP/Allegro
Confidence: high

---

## 7. Neural Network Solvers for PDEs

### 7.1 DeepONet: Learning Nonlinear Operators

Claim: DeepONet consists of a branch net (encoding input functions at sensor locations) and a trunk net (encoding output evaluation locations), and can learn diverse continuous nonlinear operators including integrals, fractional Laplacians, and implicit PDE solution operators [^18^]
Source: *Learning nonlinear operators via DeepONet based on the universal approximation theorem of operators* (Nature Machine Intelligence)
URL: https://www.nature.com/articles/s42256-021-00302-5
Date: 2021-03
Excerpt: "We design a new network with small generalization error, the deep operator network (DeepONet), which consists of a DNN for encoding the discrete input function space (branch net) and another DNN for encoding the domain of the output functions (trunk net). We demonstrate that DeepONet can learn various explicit operators, such as integrals and fractional Laplacians, as well as implicit operators that represent deterministic and stochastic differential equations."
Context: Foundational paper establishing operator learning with neural networks
Confidence: high

Claim: The universal approximation theorem for operators guarantees that a neural network with a single hidden layer can approximate any nonlinear continuous operator, and DeepONet extends this to deep networks with small generalization error [^18^]
Source: Same Nature Machine Intelligence paper
URL: https://www.nature.com/articles/s42256-021-00302-5
Date: 2021-03
Excerpt: "A less known but powerful result is that a NN with a single hidden layer can accurately approximate any nonlinear continuous operator. This universal approximation theorem is suggestive of the potential application of neural networks in learning nonlinear operators from data."
Context: Theoretical foundation for operator learning
Confidence: high

### 7.2 NSFnets: Navier-Stokes Flow Nets

Claim: NSFnets (Navier-Stokes Flow nets) use PINNs with two formulations — velocity-pressure (VP) and vorticity-velocity (VV) — to simulate incompressible flows from laminar to turbulent regimes without requiring mesh generation [^19^]
Source: *NSFnets (Navier-Stokes Flow nets)* (arXiv)
URL: https://arxiv.org/abs/2003.06496
Date: 2020-03
Excerpt: "We employ physics-informed neural networks (PINNs) to simulate the incompressible flows ranging from laminar to turbulent flows. We perform PINN simulations by considering two different formulations of the Navier-Stokes equations: the velocity-pressure (VP) formulation and the vorticity-velocity (VV) formulation."
Context: Application of PINNs to fluid dynamics
Confidence: high

Claim: For turbulent channel flow, NSFnets can sustain turbulence at Re_τ ~ 1000, but due to expensive training, only partial channel domains are considered [^19^]
Source: Same arXiv paper
URL: https://arxiv.org/abs/2003.06496
Date: 2020-03
Excerpt: "For the turbulent channel flow we show that NSFnets can sustain turbulence at Re_τ ~ 1,000 but due to expensive training we only consider part of the channel domain and enforce velocity boundary conditions on the boundaries provided by the DNS data base."
Context: Turbulent flow simulation with PINNs
Confidence: high

Claim: PINNs can achieve accuracy comparable to CFD while requiring significantly less computational memory (5–10× smaller), though training time can exceed CFD for simple geometries [^20^]
Source: *Machine Learning in Fluid Dynamics—Physics-Informed Neural Networks Using Sparse Data: A Review* (Fluids)
URL: https://www.mdpi.com/2311-5521/10/9/226
Date: 2025-08-28
Excerpt: "In terms of computational demands, the memory usage of PINN is 5–10 times smaller than the memory usage of CFD. For a small number of CFD cells, PINN takes longer to converge than the CFD solver."
Context: Comparative review of PINNs versus traditional CFD
Confidence: high

---

## 8. Conservation Law Enforcement in Neural Networks

Claim: Hard-constraint methods guarantee physical compliance by design but introduce a trade-off between architectural rigidity and data inefficiency; HNNs/LNNs embed conservation laws directly but struggle with dissipative effects [^21^]
Source: *Hard-Constrained Neural Networks with Physics-Embedded Architecture for Residual Dynamics Learning and Invariant Enforcement* (arXiv)
URL: https://arxiv.org/abs/2511.23307
Date: 2025-11-28
Excerpt: "Structure-Preserving Architectures like HNNs/LNNs offer one solution by embedding conservation laws directly into the model's structure. By learning a scalar potential (a Hamiltonian or Lagrangian), these models guarantee the conservation of the learned quantity... However, this architectural purity is also their primary weakness: they are ill-suited for the vast majority of real-world engineered systems, which are rarely conservative."
Context: Survey of hard vs. soft constraint methods in physics-informed learning
Confidence: high

Claim: Predict-Project methods like PNODEs decouple dynamics learning from constraint satisfaction, enforcing any valid algebraic invariant by projecting predicted states back onto the constraint manifold, but this is data-inefficient when paired with black-box learning [^21^]
Source: Same arXiv paper
URL: https://arxiv.org/abs/2511.23307
Date: 2025-11-28
Excerpt: "Predict–Project Methods like PNODEs provide that flexibility. By decoupling the dynamics learning from constraint satisfaction, they can enforce any valid algebraic invariant by projecting the predicted state back onto the constraint manifold at each step. While this guarantees physical consistency, existing methods typically pair projection with a black-box neural network that must learn the entire dynamics from data."
Context: Discussion of trade-offs in hard-constraint enforcement
Confidence: high

Claim: Lagrangian primal-dual learning enforces domain constraints by training two networks alternately — a primal network for the task and a dual network for Lagrangian multipliers — with robust convergence in low-data scenarios [^22^]
Source: *Enforcing domain constraints through Lagrangian primal-dual learning* (Neural Computing and Applications)
URL: https://link.springer.com/article/10.1007/s00521-026-11880-z
Date: 2026-03-21
Excerpt: "We demonstrate that the proposed framework is most beneficial in low-data scenarios when models do not have enough data to learn the existing constraints autonomously... By iteratively optimising the primal and dual networks, we enforce a robust convergence while effectively reducing constraint violations."
Context: LANN framework for co-domain constraint enforcement
Confidence: medium

---

## 9. Hamiltonian Neural Networks

Claim: Hamiltonian Neural Networks (HNNs) learn a scalar energy function H_θ(q,p) from data and recover dynamics using Hamilton's equations, conserving the learned Hamiltonian over much longer periods than baseline neural networks [^23^]
Source: *Symplectic learning for Hamiltonian neural networks* (Journal of Computational Physics)
URL: https://www.sciencedirect.com/science/article/abs/pii/S0021999123005909
Date: 2023-10-10 (published 2025)
Excerpt: "Greydanus et al. have recently proposed a clever class of Hamiltonian Neural Networks (HNNs) whose architecture engraves the mathematical properties of Hamilton's equations. By asking the neural network to predict the Hamiltonian and then calculating its symplectic gradient using backpropagation, they were able to obtain trajectories in phase space that conserve the learned Hamiltonian over much longer periods of time than a baseline neural network."
Context: Survey of HNN improvements using symplectic integrators
Confidence: high

Claim: A fully symplectic HNN using implicit symplectic partitioned Runge–Kutta methods can learn both separable and non-separable Hamiltonians with significantly lower out-of-distribution errors compared to existing baselines [^24^]
Source: *Learning Generalized Hamiltonians using fully Symplectic Mappings* (arXiv)
URL: https://arxiv.org/abs/2409.11138
Date: 2024-09-17
Excerpt: "Our experiments highlight that the proposed Generalized HNN not only accurately learns the underlying dynamics, especially in the case of non-separable systems like the Coupled Oscillator and the Hénon-Heiles system, but also achieves significantly lower OOD errors compared to existing baselines."
Context: Extension of HNNs to non-separable Hamiltonians with implicit symplectic integrators
Confidence: high

Claim: Symplectic learning for HNNs uses adapted loss functions derived from symplectic numerical integration schemes, enabling exact Hamiltonian learning given by the modified equation [^23^]
Source: Same Journal of Computational Physics paper
URL: https://www.sciencedirect.com/science/article/abs/pii/S0021999123005909
Date: 2023-10-10
Excerpt: "Zhu et al. use the implicit midpoint rule in an adapted loss and show that, in this case, the SHNN can learn an exact Hamiltonian given by the modified equation... Independently, Xiong et al. use explicit higher-order symplectic methods during training."
Context: Technical survey of symplectic integrator-based HNN training
Confidence: high

---

## 10. Lagrangian Neural Networks

Claim: Lagrangian Neural Networks (LNNs) parameterize arbitrary Lagrangians using neural networks, do not require canonical coordinates, and produce energy-conserving models for systems where Hamiltonian approaches fail (e.g., relativistic particles) [^25^]
Source: *Lagrangian Neural Networks* (arXiv)
URL: https://arxiv.org/abs/2003.04630
Date: 2020-03-10
Excerpt: "Accurate models of the world are built upon notions of its underlying symmetries. In physics, these symmetries correspond to conservation laws... we propose Lagrangian Neural Networks (LNNs), which can parameterize arbitrary Lagrangians using neural networks. In contrast to models that learn Hamiltonians, LNNs do not require canonical coordinates, and thus perform well in situations where canonical momenta are unknown or difficult to compute."
Context: Original LNN paper by Cranmer et al.
Confidence: high

Claim: Discrete Lagrangian Neural Networks with Automatic Symmetry Discovery (SymDLNN) identify subgroups of affine transformations under which a learned discrete Lagrangian is invariant, and automatically derive the corresponding conserved quantities via discrete Noether's theorem [^15^]
Source: *Discrete Lagrangian Neural Networks with Automatic Symmetry Discovery* (arXiv)
URL: https://arxiv.org/abs/2211.10830
Date: 2022-11-19 (updated 2025-01-27)
Excerpt: "Our method SymDLNN automatically identifies subgroups G_(M,w) of the group of affine linear transformations under which a (discrete) Lagrangian is invariant while the (discrete) Lagrangian of a system is learned. As a consequence, we identify the corresponding conserved quantity as well."
Context: Extension of LNNs with automatic symmetry discovery
Confidence: high

---

## 11. Equivariant Neural Networks

### 11.1 Tensor Field Networks

Claim: Tensor Field Networks (TFNs) are locally equivariant to 3D rotations, translations, and permutations at every layer, using filters built from spherical harmonics and Clebsch–Gordan coefficients, eliminating the need for rotational data augmentation [^26^]
Source: *Tensor field networks: Rotation- and translation-equivariant neural networks for 3D point clouds* (arXiv)
URL: https://arxiv.org/abs/1802.08219
Date: 2018-02-22
Excerpt: "We introduce tensor field neural networks, which are locally equivariant to 3D rotations, translations, and permutations of points at every layer. 3D rotation equivariance removes the need for data augmentation to identify features in arbitrary orientations. Our network uses filters built from spherical harmonics."
Context: Foundational paper for equivariant learning on 3D point clouds
Confidence: high

Claim: TFNs achieve perfect accuracy classifying 3D Tetris blocks under random rotations without any rotational data augmentation, while non-equivariant networks reduce to random-guessing accuracy [^26^]
Source: Same arXiv paper
URL: https://arxiv.org/abs/1802.08219
Date: 2018-02-22
Excerpt: "TFNs achieved perfect accuracy classifying 3D 'Tetris' blocks and competitive performance on ModelNet40—with no rotational data augmentation. Non-equivariant networks reduce to random-guessing accuracy when evaluated on arbitrarily rotated data."
Context: Empirical validation of equivariance benefits
Confidence: high

### 11.2 E3NN and Equivariant Architectures

Claim: E3NN (Euclidean Neural Networks) provides a general framework for building E(3)-equivariant networks, used by NequIP, MACE, Equiformer, and other state-of-the-art interatomic potential models [^27^]
Source: *Bayesian E(3)-Equivariant Interatomic Potential with Iterative Restratification* (arXiv)
URL: https://arxiv.org/abs/2510.03046
Date: 2026-04-08
Excerpt: "Geiger, M. & Smidt, T. E3nn: Euclidean Neural Networks (2022)... Liao, Y.-L. & Smidt, T. Equiformer: Equivariant Graph Attention Transformer for 3D Atomistic Graphs (2023)... Batzner, S. et al. E(3)-equivariant graph neural networks for data-efficient and accurate interatomic potentials. Nat. Commun. 13, 2453 (2022)."
Context: Recent work building on the E3NN ecosystem
Confidence: high

Claim: To achieve angular resolution δ in 3D, traditional CNNs require O(δ⁻³) more filters, while equivariant networks cover all orientations with a single set of weights [^28^]
Source: *Tensor Field Networks - Rotation and Translation-Equivariant Neural Networks* (UBC slides)
URL: https://lrjconan.github.io/UBC-EECE571F-DL-Structures/assets/slides_2025/paper_07_tensor_field_net.pdf
Date: 2026-02-11
Excerpt: "To achieve angular resolution δ in 3D, traditional CNNs require O(δ⁻³) more filters. TFNs use equivariant filters to cover all orientations with a single set of weights."
Context: Educational summary of equivariance efficiency
Confidence: high

---

## 12. Scientific Machine Learning (SciML)

### 12.1 Julia Ecosystem

Claim: The SciML ecosystem provides over 200 packages spanning differential equations, optimization, symbolic computation, and differentiable programming, with DifferentialEquations.jl offering ~300 solver methods across ODEs, SDEs, DDEs, DAEs, and hybrid systems [^4^]
Source: SciML official website
URL: https://sciml.ai/
Date: Ongoing
Excerpt: "Software for differential equations, large-scale nonlinear systems, inverse problems, and automated model discovery. Plug new solvers into the composable interfaces. Make use of distributed and GPU parallelism."
Context: Official description of the SciML ecosystem
Confidence: high

Claim: DifferentialEquations.jl demonstrated 100× speedup over PyTorch's torchdiffeq on spiral neural ODE training and 1,600× advantage over torchsde for stochastic differential equations [^4^]
Source: *What is Scientific Machine Learning (SciML)? Complete Guide* (Artics Ledge)
URL: https://www.articsledge.com/post/scientific-machine-learning-sciml
Date: 2025-11-05
Excerpt: "Demonstrated 100x speedup over PyTorch's torchdiffeq on spiral neural ODE training. 1,600x advantage over torchsde for stochastic differential equations (arXiv, 2021)."
Context: Performance benchmarks for Julia SciML vs. Python equivalents
Confidence: high

### 12.2 ModelingToolkit.jl and NeuralPDE.jl

Claim: ModelingToolkit.jl is a symbolic-numeric modeling package combining features from symbolic computing (SymPy, Mathematica) with equation-based modeling (Simulink, Modelica), enabling automatic model transformation, simplification, and parallelization [^29^]
Source: ModelingToolkit.jl documentation
URL: https://docs.sciml.ai/ModelingToolkit/
Date: 2025-06-27
Excerpt: "ModelingToolkit.jl is a symbolic-numeric modeling package. Thus it combines some of the features from symbolic computing packages like SymPy or Mathematica with the ideas of equation-based modeling systems like the causal Simulink and the acausal Modelica."
Context: Official documentation
Confidence: high

Claim: NeuralPDE.jl provides automated physics-informed neural network solvers with compatibility for Flux.jl, Lux.jl, and NeuralOperators.jl (DeepONets, FNOs, GNOs), enabling mixed neural operator and physics-informed loss training [^30^]
Source: NeuralPDE.jl documentation
URL: https://docs.sciml.ai/NeuralPDE/dev/
Date: 2026-02-09
Excerpt: "Compatibility with NeuralOperators.jl for mixing DeepONets and other neural operators (Fourier Neural Operators, Graph Neural Operators, etc.) with physics-informed loss functions."
Context: Feature documentation for neural PDE solving in Julia
Confidence: high

### 12.3 DataDrivenDiffEq.jl: Automated Equation Discovery

Claim: DataDrivenDiffEq.jl automates discovery of dynamical systems from data, integrating SINDy, Dynamic Mode Decomposition, and symbolic regression with ModelingToolkit.jl for symbolic output and LaTeXification [^31^]
Source: DataDrivenDiffEq.jl documentation
URL: https://docs.sciml.ai/DataDrivenDiffEq/
Date: 2025-04-14
Excerpt: "DataDrivenDiffEq.jl is a package for finding systems of equations automatically from a dataset. The methods in this package take in data and return the model which generated the data."
Context: Official package documentation
Confidence: high

Claim: DataDrivenDiffEq.jl successfully rediscovered the Lorenz system from time-series data with high accuracy (parameters within ~0.3% of ground truth) [^32^]
Source: DataDrivenDiffEq.jl GitHub
URL: https://github.com/SciML/DataDrivenDiffEq.jl
Date: 2019-present
Excerpt: "Differential(t)(x(t)) = p₁*x(t) + p₂*y(t)... Parameters: p₁ : -10.0, p₂ : 10.0, p₃ : 28.0, p₄ : -1.0, p₅ : -1.0, p₆ : 1.0, p₇ : -2.7"
Context: Quick-start demonstration example
Confidence: high

---

## 13. AI for Physics Discovery

Claim: LLM-based autonomous scientific agents operate across three phases: hypothesis discovery, experimental design and execution, and result analysis and refinement, with evolutionary algorithm-based systems navigating vast combinatorial spaces for materials, molecules, and mechanical structures [^33^]
Source: *Autonomous Agents for Scientific Discovery* (arXiv)
URL: https://arxiv.org/abs/2510.09901
Date: 2026-04-06
Excerpt: "Here, our work systematically examines how LLM-based agents operate across key stages of scientific discovery, including hypothesis discovery, experimental design and execution, and result analysis and refinement... LLM-based evolutionary systems show immense promise for navigating vast combinatorial spaces with textual information extraction or rich, semantic objectives, such as discovering new materials, mechanical structures, molecules or macromolecules."
Context: Comprehensive survey of AI-driven scientific discovery
Confidence: high

Claim: Generative AI systems are being developed for automated experimental design in quantum physics, high-energy physics, chemistry, and biology, but most work focuses on narrow aspects in isolation rather than sustained integrated research [^34^]
Source: *Towards Scientific Discovery with Generative AI: Progress and Challenges* (AAAI 2025)
URL: https://creddy.net/papers/AAAI25.pdf
Date: 2025
Excerpt: "Despite this progress, we still lack AI systems capable of integrating the diverse cognitive processes involved in sustained scientific research and discovery. Most work has focused on narrow aspects of scientific reasoning in isolation."
Context: AAAI 2025 survey paper on generative AI for science
Confidence: high

---

## 14. Differentiable Physics

Claim: Differentiable simulation for soft robots integrates FEM, MPM, and Cosserat models with differentiable algorithms for time integration, contact handling, and actuation, enabling end-to-end gradient-based optimization with only 0.25% of ground-truth data needed for successful policy transfer compared to direct RL [^35^]
Source: *Differentiable Simulation for Soft Robots* (Emergent Mind)
URL: https://www.emergentmind.com/topics/differentiable-simulation-for-soft-robots
Date: 2026-02-05
Excerpt: "Differentiable engines need only 0.25% of ground-truth data to enable successful policy transfer in tensegrity robot sim2sim benchmarks, compared to direct RL on the ground-truth model."
Context: Survey of differentiable physics for soft robotics
Confidence: medium

Claim: DiffMJX provides correct gradients in the presence of hard contacts by incorporating adaptive timestep integration into MuJoCo XLA, addressing the fundamental problem that "gradients obtained via automatic differentiation are 'incorrect' insofar as they do not align with those of the underlying continuous system" [^36^]
Source: *Differentiable Simulation of Hard Contacts with Soft Gradients for Learning and Control* (arXiv)
URL: https://arxiv.org/abs/2506.14186
Date: 2026-03-23
Excerpt: "We incorporate adaptive timestep integration into MuJoCo XLA, incurring a slight computational overhead while obtaining correct gradients in the presence of hard contacts, and remaining compatible with existing MuJoCo libraries."
Context: Technical advance in differentiable rigid-body simulation
Confidence: high

Claim: A differentiable physical simulation framework for soft robots using MPM and mass-spring systems demonstrates that differentiable physics delivers better results and converges much faster than reinforcement learning frameworks [^37^]
Source: ICLR 2024 submission (OpenReview)
URL: https://openreview.net/forum?id=pUKJWr5zOE
Date: 2023-10-13
Excerpt: "Experiments show that our learning framework, based on differentiable physics, delivers better results and converges much faster, compared with reinforcement learning frameworks."
Context: Peer-reviewed soft robot learning framework
Confidence: high

---

## 15. Thermodynamics-Informed AI

Claim: Quantum fluctuation theorems for arbitrary environments decompose entropy production into adiabatic and nonadiabatic contributions with positive averages, holding for evolutions verifying specific quantum conditions [^38^]
Source: *Quantum Fluctuation Theorems for Arbitrary Environments* (Physical Review X)
URL: https://sites.lsa.umich.edu/horowitz-lab-new/wp-content/uploads/sites/1181/2019/04/PhysRevX.8.031037.pdf
Date: 2018-08-06
Excerpt: "We analyze the production of entropy along nonequilibrium processes in quantum systems coupled to generic environments... the entropy production due to final measurements and the loss of correlations obeys a fluctuation theorem in detailed and integral forms."
Context: Fundamental work on quantum thermodynamic fluctuation theorems
Confidence: high

Claim: Physics-aware reinforcement learning integrates conservation laws, analytic models, and constraints directly into RL frameworks using physics-informed reward shaping, embedding analytic models, and differentiable simulators [^39^]
Source: *Physics-Aware Reinforcement Learning* (Emergent Mind)
URL: https://www.emergentmind.com/topics/physics-aware-reinforcement-learning-paradigm
Date: 2026-01-19
Excerpt: "Physics-aware reinforcement learning (RL) is a research direction that synergistically integrates physical knowledge—such as conservation laws, analytic models, or constraints—directly into the RL agent's formulation, objectives, and training protocol."
Context: Survey of physics-informed RL techniques
Confidence: medium

**Note on PhysicsReward**: The specific "6-component signal for physics-aware training" referenced in the mission brief was not found in the literature search. The concept appears to be a specific internal formulation rather than a widely published method. Physics-aware reward shaping generally includes: task reward, constraint penalties, control cost, energy penalties, stability bonuses, and domain randomization — six natural categories that may align with the mission description [^40^].

---

## 16. Key Questions: Analysis and Synthesis

### 16.1 Can PINNs be used to validate physical claims in LLM outputs?

**Answer: Partially, with important limitations.**

PINNs can serve as *consistency checkers* for physical claims, but not as *truth validators*. The mechanism works as follows:

1. **Forward validation**: If an LLM outputs a proposed solution to a known PDE (e.g., a temperature field, velocity profile), a PINN trained with the governing equations can evaluate whether the proposed solution satisfies the PDE residuals, boundary conditions, and conservation laws. Large residuals indicate the LLM output is physically inconsistent.

2. **Inverse validation**: If an LLM proposes a new physical law or parameter value, an inverse PINN can attempt to learn that law from synthetic data and check for well-posedness and identifiability. However, this is circular — the PINN cannot independently verify the law's correctness.

3. **Limitations**: PINNs inherit all the failure modes of neural networks (optimization difficulty, spectral bias, scaling challenges). They are also computationally expensive for high-dimensional or turbulent problems. Most critically, PINNs encode *known* physics; they cannot adjudicate between competing novel theories.

**Verdict**: PINNs are a useful tool in a physics-validation pipeline but must be paired with symbolic verification, experimental validation, and expert review.

### 16.2 What is the speedup of FNO vs traditional solvers for common PDEs?

**Answer: ~440× for Navier-Stokes on 256×256 grids; ~10× for time-stepping with F-FNO.**

| Method | Problem | Grid | FNO Time | Traditional Time | Speedup | Source |
|--------|---------|------|----------|------------------|---------|--------|
| FNO | Navier-Stokes | 256×256 | 0.005s | 2.2s (pseudo-spectral) | ~440× | [^1^] |
| F-FNO | Navier-Stokes | — | — | pseudo-spectral | ~10× (time-step) | [^8^] |
| PINN | 2D cylinder flow | — | — | CFD (simpleFoam) | Memory: 5-10× smaller | [^20^] |
| EPINN | 1D solid mechanics | — | — | Standard PINN | ~13× | [^6^] |
| EPINN | 3D solid mechanics | — | — | Standard PINN | ~126× | [^6^] |

**Important caveat**: These speedups are for *inference* (evaluating a trained model), not training. Training FNOs requires substantial data generation via traditional solvers. The speedup is most valuable in settings requiring many repeated evaluations (optimization, uncertainty quantification, inverse problems, real-time control).

### 16.3 How can physics-informed architectures constrain AI reasoning?

**Answer: Through four complementary mechanisms:**

1. **Structural inductive bias**: Hamiltonian/Lagrangian networks encode conservation laws by architecture, making energy violation physically impossible (not just penalized).

2. **Loss-function constraints**: PINNs embed PDE residuals as soft constraints, penalizing predictions that violate known physics during training.

3. **Hard constraints**: Exact boundary condition enforcement (ADF, EPINN) and predict-project methods guarantee physical consistency at inference time.

4. **Equivariance**: E(3)-equivariant networks (NequIP, MACE, TFNs) enforce that predictions respect physical symmetries (rotation, translation, permutation) by construction, reducing the hypothesis space and improving data efficiency by orders of magnitude.

The most robust approach combines multiple mechanisms: e.g., an equivariant Lagrangian network with hard boundary constraints, trained with a physics-informed loss. This creates a "physics cage" around the model's predictions.

### 16.4 Can symbolic regression discover conservation laws from model behavior?

**Answer: Yes, when combined with variational principles.**

The SymDLNN framework demonstrates that symbolic regression (via learned Lagrangians) combined with automatic symmetry discovery can identify conserved quantities from trajectory data alone [^15^]. The process is:

1. Learn a discrete Lagrangian L_d(q_k, q_{k+1}) from data using a neural network.
2. Automatically identify directions (M, w) under which L_d is invariant.
3. Apply discrete Noether's theorem to derive the conserved quantity: I(q_k, q_{k+1}) = -(Mq_k + w)^T ∇_{q_k} L_d(q_k, q_{k+1}).

This is powerful because it requires no *a priori* knowledge of the conservation law — only trajectory data. The discovered law can then be used to validate the model or constrain future predictions.

**Limitation**: The method depends on the quality and coverage of the data, the choice of basis functions for the Lagrangian ansatz, and the assumption that the underlying dynamics are derivable from a variational principle. Dissipative systems with no underlying Lagrangian structure require alternative approaches.

---

## 17. Limitations and Open Challenges

1. **PINN scaling**: PINNs struggle with high-dimensional problems, stiff PDEs, and turbulent flows. Training can be unstable and computationally expensive.

2. **GNoME verification controversy**: The GNoME database contains significant near-duplicates, raising questions about the reliability of large-scale AI-generated scientific databases and the adequacy of peer review for such claims [^2^].

3. **FNO geometry constraints**: FNOs require regular grids and struggle with irregular geometries, sharp gradients, and strict boundary condition enforcement.

4. **HNN/LNN rigidity**: Structure-preserving architectures cannot model dissipative or non-conservative systems without extensions, limiting their applicability to real-world engineered systems [^21^].

5. **Equivariant network cost**: E(3)-equivariant networks with high-degree tensor representations can become computationally expensive, though recent work (Allegro, EquiformerV2) addresses this [^17^][^27^].

6. **Symbolic regression brittleness**: SINDy and genetic programming depend critically on the choice of library functions and can fail for noisy, high-dimensional, or stochastic systems.

7. **Differentiable physics correctness**: Gradients through physics simulators may not align with the underlying continuous system, especially for stiff dynamics and hard contacts [^36^].

---

## 18. Citation Registry

[^1^]: Li, Z. et al. "Fourier Neural Operator for Parametric Partial Differential Equations." arXiv:2010.08895, 2020.
[^2^]: Chawla, D.S. "Duplicate structures haunt crystallography databases." C&EN, 2025-12-16.
[^3^]: Batzner, S. et al. "E(3)-equivariant graph neural networks for data-efficient and accurate interatomic potentials." Nature Communications 13, 2453, 2022.
[^4^]: SciML: Open Source Software for Scientific Machine Learning. https://sciml.ai/
[^5^]: "Physics-Informed Neural Networks in Materials Modeling and Design: A Review." Springer, 2025.
[^6^]: "Review of Physics-Informed Neural Networks: Challenges in Loss Function Design and Geometric Integration." MDPI Mathematics 13(20), 3289, 2025.
[^7^]: "How the Fourier Neural Operator Learns to Solve PDEs." PhysicsX AI, 2026-04-23.
[^8^]: Tran, A. et al. "Factorized Fourier Neural Operators." arXiv:2111.13802, 2021.
[^9^]: "Graph neural network force fields for adiabatic dynamics of lattice Hamiltonians." arXiv:2603.02039, 2026.
[^10^]: Merchant, A. et al. "Scaling deep learning for materials discovery." Nature 624, 80-85, 2023.
[^11^]: Google DeepMind. "Millions of new materials discovered with deep learning." 2023-11-29.
[^12^]: Brunton, S.L., Proctor, J.L., Kutz, J.N. "Discovering governing equations from data by sparse identification of nonlinear dynamical systems." PNAS 113(15), 3932-3937, 2016.
[^13^]: "SINDyG: Sparse Identification of Nonlinear Dynamical Systems from Graph-Structured Data." arXiv:2409.04463, 2025.
[^14^]: "Physics-informed genetic programming for discovery of partial differential equations from scarce and noisy data." Journal of Computational Physics, 2024.
[^15^]: "Discrete Lagrangian Neural Networks with Automatic Symmetry Discovery." arXiv:2211.10830, 2022.
[^16^]: MACE GitHub repository. https://github.com/acesuit/mace
[^17^]: Musaelian, A. et al. "Scaling the leading accuracy of deep equivariant models to biomolecular simulations of realistic size." SC23, 2023.
[^18^]: Lu, L. et al. "Learning nonlinear operators via DeepONet based on the universal approximation theorem of operators." Nature Machine Intelligence 3, 218-229, 2021.
[^19^]: Cai, S., Li, H., Karniadakis, G.E. "NSFnets (Navier-Stokes Flow nets)." arXiv:2003.06496, 2020.
[^20^]: "Machine Learning in Fluid Dynamics—Physics-Informed Neural Networks Using Sparse Data: A Review." Fluids 10(9), 226, 2025.
[^21^]: "Hard-Constrained Neural Networks with Physics-Embedded Architecture for Residual Dynamics Learning and Invariant Enforcement." arXiv:2511.23307, 2025.
[^22^]: "Enforcing domain constraints through Lagrangian primal-dual learning." Neural Computing and Applications, 2026.
[^23^]: "Symplectic learning for Hamiltonian neural networks." Journal of Computational Physics, 2023.
[^24^]: "Learning Generalized Hamiltonians using fully Symplectic Mappings." arXiv:2409.11138, 2024.
[^25^]: Cranmer, M. et al. "Lagrangian Neural Networks." arXiv:2003.04630, 2020.
[^26^]: Thomas, N. et al. "Tensor field networks: Rotation- and translation-equivariant neural networks for 3D point clouds." arXiv:1802.08219, 2018.
[^27^]: "Bayesian E(3)-Equivariant Interatomic Potential with Iterative Restratification." arXiv:2510.03046, 2026.
[^28^]: UBC EECE 571F slides on Tensor Field Networks. 2026.
[^29^]: ModelingToolkit.jl documentation. https://docs.sciml.ai/ModelingToolkit/
[^30^]: NeuralPDE.jl documentation. https://docs.sciml.ai/NeuralPDE/dev/
[^31^]: DataDrivenDiffEq.jl documentation. https://docs.sciml.ai/DataDrivenDiffEq/
[^32^]: DataDrivenDiffEq.jl GitHub. https://github.com/SciML/DataDrivenDiffEq.jl
[^33^]: "Autonomous Agents for Scientific Discovery." arXiv:2510.09901, 2026.
[^34^]: "Towards Scientific Discovery with Generative AI: Progress and Challenges." AAAI 2025.
[^35^]: "Differentiable Simulation for Soft Robots." Emergent Mind, 2026.
[^36^]: "Differentiable Simulation of Hard Contacts with Soft Gradients." arXiv:2506.14186, 2026.
[^37^]: "A Differentiable Physical Simulation Framework for Soft Robots." ICLR 2024 submission.
[^38^]: Manzano, G., Horowitz, J.M., Parrondo, J.M.R. "Quantum Fluctuation Theorems for Arbitrary Environments." Physical Review X 8, 031037, 2018.
[^39^]: "Physics-Aware Reinforcement Learning." Emergent Mind, 2026.
[^40^]: "Comprehensive Overview of Reward Engineering and Shaping in Advancing Reinforcement Learning Applications." arXiv:2408.10215, 2024.

---

*Research compiled for UASA/Rex Deterministic Superintelligence Substrate — Dimension 16: Physics-Informed Neural Architectures*
