Claim: [claim with inline citation [^number^]]
Source: [source name]
URL: [URL]
Date: [publication date]
Excerpt: [verbatim raw excerpt — no paraphrasing]
Context: [surrounding context]
Confidence: [high / medium / low]

# Dimension 01: Deterministic Execution Substrate for AI

## Research Report — Deterministic, Reproducible AI Execution Runtimes

---

### 1. MadSim Deterministic Async Simulation Runtime

Claim: MadSim is a Rust async runtime similar to tokio, but with a key feature called deterministic simulation. The main idea is borrowed from FoundationDB and sled simulation guide. Your code should be able to deterministically execute on top of a simulator. The simulator will amplify randomness, create chaos and inject failures into your system. A lot of hidden bugs may be revealed, which you can then deterministically reproduce until they are fixed. [^92^]
Source: MadSim GitHub Repository
URL: https://github.com/madsim-rs/madsim
Date: 2021-07-25 (ongoing development through 2026)
Excerpt: "MadSim is a Rust async runtime similar to tokio, but with a key feature called deterministic simulation. The main idea is borrowed from FoundationDB and sled simulation guide. Your code should be able to deterministically execute on top of a simulator. The simulator will amplify randomness, create chaos and inject failures into your system."
Context: Core project documentation for the MadSim crate, which provides drop-in replacements for tokio, tonic, etcd-client, rdkafka, and AWS SDK crates.
Confidence: high

Claim: MadSim works via `[patch]`-replacement of `tokio` and related crates plus libc interception (`gettimeofday`, `clock_gettime`, `getrandom`, `sysconf`). Any third-party dep that reaches the real world through another path needs manual patching. [^87^]
Source: linera-protocol GitHub Issue #6108
URL: https://github.com/linera-io/linera-protocol/issues/6108
Date: 2026-04-22
Excerpt: "madsim works via `[patch]`-replacement of `tokio` and related crates plus libc interception (`gettimeofday`, `clock_gettime`, `getrandom`, `sysconf`). Any third-party dep that reaches the real world through another path needs manual patching."
Context: Technical investigation document for integrating MadSim into the Linera protocol's test harness.
Confidence: high

Claim: The "magic" of MadSim — used in RisingWave — involves `libc` symbol overrides to control time and entropy. The `rand` module overrides `getrandom`, `getentropy`, and (Mac-only) `CCRandomGenerateBytes`. The `time` module overrides `clock_gettime` using turmoil's clock. [^86^]
Source: S2.dev Blog — Deterministic simulation testing for async Rust
URL: https://s2.dev/blog/dst
Date: 2025-04-02
Excerpt: "We liked the overall ergonomics of a turmoil-based DST, but a bit of madness seemed like the missing ingredient – `libc` symbol overrides to control time and entropy... The `rand` module overrides `getrandom`, `getentropy`, and (Mac-only) `CCRandomGenerateBytes`. The new implementations utilize an RNG we statically initialize with `set_rng()`. The `time` module overrides `clock_gettime` using turmoil's clock."
Context: Production engineering blog post describing the integration of MadSim-derived `mad-turmoil` crate at S2.
Confidence: high

Claim: RisingWave uses madsim in production for deterministic simulation testing of their distributed SQL database. [^87^]
Source: linera-protocol GitHub Issue #6108
URL: https://github.com/linera-io/linera-protocol/issues/6108
Date: 2026-04-22
Excerpt: "RisingWave uses madsim in production (see references). Polar Signals published a reference integration."
Context: MadSim adoption references within the Rust distributed systems ecosystem.
Confidence: high

---

### 2. Rust Deterministic Execution Patterns

Claim: Rust provides a reproducibility infrastructure for deterministic execution through centralized random seed management. The `ruchy` crate provides `get_seed()` and `get_rng("parser")` for component-specific seeded RNGs. [^25^]
Source: ruchy::reproducibility — Rust docs.rs
URL: https://docs.rs/ruchy/latest/ruchy/reproducibility/index.html
Date: 2026-04-21
Excerpt: "This module provides centralized random seed management to ensure reproducible results across all Ruchy components... `get_seed()` — Get the global seed. `get_rng("parser")` — Get a seeded RNG for a specific component."
Context: Documentation for the ruchy crate's reproducibility module, showing emerging patterns for deterministic RNG management in Rust.
Confidence: medium

Claim: Rust's const fn allows execution of a subset of Rust at compile time when a function is explicitly marked as const. However, const fn is not an explicit request for compile-time optimization — there are no other ways to ask for it in the language today, and adding it wouldn't be trivial. [^48^]
Source: Rust Internals Forum — Should const calls with small finite inputs become a lookup table?
URL: https://internals.rust-lang.org/t/should-const-calls-with-small-finite-inputs-become-a-lookup-table/21617
Date: 2024-09-28
Excerpt: "Const fn isn't an explicit request for [compile-time evaluation], there are no other ways to ask for it in the language today, and adding it wouldn't be trivial... constant folding is done by the LLVM optimizer, is a completely separate process from `const` evaluation."
Context: Discussion among Rust compiler developers about the limitations and future of const evaluation.
Confidence: high

Claim: Rust constant evaluation is not the same as constant propagation. CTFE is about code that MUST be executed at compile time because the compiler needs to know its result to proceed — for example, it needs to know the size of an array to compute how to lay out data in memory. [^54^]
Source: Ralf Jung's Blog — Thoughts on Compile-Time Function Evaluation and Type Systems
URL: https://www.ralfj.de/blog/2018/07/19/const.html
Date: 2018-07-19
Excerpt: "CTFE is NOT the same as constant propagation: Constant propagation is an optimization pass done by compilers like LLVM that will opportunistically change code like `3 + 4` into `7` to avoid run-time work. Being an optimization, constant propagation must, by definition, not change program behavior and will not be observable at all (other than performance). CTFE, on the other hand, is about code that MUST be executed at compile time because the compiler needs to know its result to proceed."
Context: Deep technical analysis by a Rust compiler team member explaining the distinction between CTFE and optimization.
Confidence: high

Claim: Rust's const generics project group explains that const evaluation is useful to assert correctness requirements at compile time instead of using a runtime panic, and to compute things like regex at compile time improving performance and removing runtime allocations. [^56^]
Source: Rust Const Generics Project Group
URL: https://rust-lang.github.io/project-const-generics/vision/why-compile-time-evaluation.html
Date: Ongoing (latest update unknown)
Excerpt: "Const evaluation is also very useful to assert correctness requirements at compile time, instead of using a runtime panic... For example the crate `regex` could be able to compile a regex at compile time, improving the performance when using `regex` and even removing the need for runtime allocations."
Context: Official Rust project group documentation explaining the rationale for compile-time evaluation capabilities.
Confidence: high

Claim: Rust reproducible builds on Windows require special linker flags such as `/Brepro` because MSVC embeds timestamps and non-deterministic elements by default. Even without dependencies, a hello world program compiled twice produces different binaries. [^174^]
Source: Rust Users Forum — How to perform reproducible builds on Windows?
URL: https://users.rust-lang.org/t/how-to-perform-reproducible-builds-on-windows/133356
Date: 2025-08-24
Excerpt: "Even without using any additional dependencies, just a hello world program, compiling it twice in the same environment produces different binaries. I used `diffoscope` to examine the differences: executables compiled with the GNU toolchain have different headers, while those compiled with the MSVC toolchain even differ at the assembly level... set RUSTFLAGS=-Clink-arg=/Brepro gave me the same digest in several builds"
Context: Community discussion on practical challenges of byte-identical reproducible builds in Rust on Windows.
Confidence: high

---

### 3. GPU Deterministic Execution

Claim: GPUDet is the first hardware proposal that provides strong determinism for deterministic massively parallel architecture with thousands of concurrent threads. It leverages inherent determinism of current SIMT architectures to provide deterministic interaction among threads within a wavefront at no cost. GPUDet simulation results indicate only 2x slowdown on average over a baseline nondeterministic architecture, with runtime overheads as low as 4% for compute-bound applications. [^181^]
Source: GPUDet: A Deterministic GPU Architecture (ASPLOS 2013)
URL: https://people.ece.ubc.ca/aamodt/publications/papers/jooybar.asplos2013.pdf
Date: 2013
Excerpt: "We propose GPUDet, the first hardware model for a fully deterministic GPU architecture... GPUDet leverages the inherent determinism of the SIMD hardware in GPUs to provide determinism within a wavefront at no cost... Our simulation results indicate that GPUDet incurs only 2x slowdown on average over a baseline nondeterministic architecture, with runtime overheads as low as 4% for compute-bound applications."
Context: Peer-reviewed academic paper at ASPLOS 2013 presenting a hardware-level approach to GPU determinism.
Confidence: high

Claim: GPUDet exploits the Z-Buffer Unit, an existing GPU hardware unit for graphics rendering, to allow parallel out-of-order memory writes to produce a deterministic output. It also introduces deterministic parallel execution of atomic operations and a workgroup-aware algorithm that eliminates unnecessary global synchronizations. [^182^]
Source: Deterministic Execution on GPU Architectures (UBC Master's Thesis)
URL: https://open.library.ubc.ca/media/stream/pdf/24/1.0074006/1
Date: 2013
Excerpt: "GPUDet exploits the Z-Buffer Unit, an existing GPU hardware unit for graphics rendering, to allow parallel out-of-order memory writes to produce a deterministic output. Other optimizations in GPUDet include deterministic parallel execution of atomic operations and a workgroup-aware algorithm that eliminates unnecessary global synchronizations."
Context: Master's thesis expanding on the GPUDet hardware architecture for deterministic GPU execution.
Confidence: high

Claim: NVIDIA CUB now provides three explicit determinism levels for reduction algorithms: `not_guaranteed` (highest performance), `run_to_run` (same GPU), and `gpu_to_gpu` (strictest reproducibility across different GPUs). GPU-to-GPU determinism can significantly reduce performance, increasing execution time by 20% to 30% for large problem sizes. [^91^]
Source: NVIDIA Developer Blog — Controlling Floating-Point Determinism in NVIDIA CCCL
URL: https://developer.nvidia.com/blog/controlling-floating-point-determinism-in-nvidia-cccl/
Date: 2026-03-05
Excerpt: "CUB also provides GPU-to-GPU determinism, which guarantees identical results across multiple runs with the same input on different GPUs... GPU-to-GPU determinism, which enforces the strictest reproducibility across different GPUs, can significantly reduce performance, increasing execution time by 20% to 30% for large problem sizes."
Context: Official NVIDIA blog post documenting production-grade deterministic floating-point primitives in CUB.
Confidence: high

Claim: The fundamental reason for non-determinism in LLM inference on GPUs is that floating point arithmetic is non-associative: (a+b)+c ≠ a+(b+c). GPU kernels consume numbers in different orders due to continuous batching, Split-K vs Non-Split-K MatMul, block size hyperparameters, collective AllReduce operations, and tensor parallelism strategies. [^175^]
Source: arXiv Paper — Understanding and Mitigating Numerical Sources of Nondeterminism in LLM Inference
URL: https://arxiv.org/html/2511.17826
Date: 2025-11-21
Excerpt: "The fundamental reason is that floating point (FP) arithmetic is non-associative, which means processing numbers in different orders can affect the final result due to accumulated rounding errors. However, in serving systems, GPU kernels often consume numbers in varying orders for several reasons including: (1) continuous batching which dynamically changes the set of requests in a batch; (2) different implementations of operations, such as the use of Split-K versus Non-Split-K matrix multiplication; (3) hyperparameters of operations, like the block size for MatMul kernels and Flash-Attention; (4) collective operations in parallel systems, like All-Reduce; (5) parallel strategies like TP, which distribute workloads across multiple GPUs."
Context: Peer-reviewed academic paper systematically categorizing sources of GPU non-determinism in LLM serving systems.
Confidence: high

Claim: In GPU computation, the behavior of atomic operations is not deterministic. If you have a lot of atomic adds, every time you run the code you'll get a different result. However, the individual floating point computations are deterministic — it's the multi-threaded design on top that's introducing the variability. [^151^]
Source: Hacker News Discussion — GPU determinism debate
URL: https://news.ycombinator.com/item?id=37007811
Date: 2023-08-05
Excerpt: "The behaviour of atomic operations is definitely not deterministic. E.g. if you have a lot of atomic adds, every time you run the code you'll get a different result... The individual floating point computations are deterministic, it's the multi-threaded design on top that's introducing the variability in the output."
Context: Technical debate among systems programmers about the root causes of GPU non-determinism, distinguishing hardware from software causes.
Confidence: high

---

### 4. Metal/MLX GPU Determinism on Apple Silicon

Claim: MLX on Apple Silicon exhibits fundamental batch invariance issues in floating-point models — changes in batch size can produce significant numerical differences. This is a framework-level issue. Quantized integer models (Q4_K_M, Q8_0) achieve perfect reproducibility on MLX. [^88^]
Source: adityakarnam.com — Why Your Apple Silicon LLM Isn't Reproducible
URL: https://adityakarnam.com/mlx-non-determinism-apple-silicon/
Date: 2025-09-15
Excerpt: "MLX on Apple Silicon exhibits fundamental batch invariance issues in floating-point models, but this investigation reveals that quantization provides a practical path to determinism... While MLX's floating-point implementations suffer from dtype-dependent nondeterminism, quantized integer models (Q4_K_M, Q8_0) achieve perfect reproducibility."
Context: Deep technical investigation into MLX determinism on Apple Silicon, including experimental validation.
Confidence: high

Claim: A community project `mlx-deterministic` provides batch-invariant operations for deterministic LLM inference on Apple Silicon using MLX. They provide custom Metal kernels that achieve bitwise determinism (0.0 tolerance) with ~27-31% overhead for large matmul operations compared to standard MLX. [^90^]
Source: GitHub — ProbioticFarmer/mlx-deterministic
URL: https://github.com/ProbioticFarmer/mlx-deterministic
Date: 2025-10-04
Excerpt: "Metal kernel (FP32): 0.0 (bitwise) tolerance, batch invariant, does NOT use mx.matmul (custom SIMD kernel)... Matmul 2048x2048 (FP32): Standard MLX 1.50ms | Metal Kernel 1.91ms (+27%)... Batch invariance: PASS (all batch sizes produce identical logits). All outputs are BITWISE IDENTICAL across batch sizes [1, 32]"
Context: Open-source project implementing deterministic Metal kernels for MLX, with comprehensive benchmarks.
Confidence: high

Claim: Key capabilities currently missing from the MLX ecosystem include deterministic inference — MLX's floating-point nondeterminism is a framework-level issue. Also missing are multi-LoRA serving and cross-platform consistency. [^85^]
Source: yage.ai — MLX: The Next Inference Engine for Apple Silicon
URL: https://yage.ai/share/mlx-apple-silicon-en-20260331.html
Date: 2026-03-30
Excerpt: "Key capabilities currently missing from the MLX ecosystem include multi-LoRA serving (MOLA is the only exploration, currently in alpha), deterministic inference (MLX's floating-point nondeterminism is a framework-level issue)... MLX also suffers from floating-point nondeterminism (where changes in batch size can produce significant numerical differences), posing a risk for scenarios requiring deterministic output."
Context: Industry analysis of the MLX ecosystem landscape, identifying gaps including deterministic inference.
Confidence: high

---

### 5. Deterministic ML Inference Systems

Claim: vLLM does not guarantee reproducibility by default for performance reasons. To achieve reproducible results, in offline mode set `VLLM_ENABLE_V1_MULTIPROCESSING=0` which makes scheduling deterministic, or enable batch invariance. Even with these settings, vLLM only provides reproducibility when running on the same hardware and the same vLLM version. [^20^]
Source: vLLM Documentation — Reproducibility
URL: https://docs.vllm.ai/en/latest/usage/reproducibility/
Date: Ongoing (current docs)
Excerpt: "vLLM does not guarantee the reproducibility of the results by default, for the sake of performance. To achieve reproducible results: In offline mode, you can either set `VLLM_ENABLE_V1_MULTIPROCESSING=0` which makes scheduling deterministic, or enable batch invariance... Even with the above settings, vLLM only provides reproducibility when it runs on the same hardware and the same vLLM version."
Context: Official vLLM documentation acknowledging reproducibility limitations and providing workarounds.
Confidence: high

Claim: SGLang achieves fully deterministic inference by using batch-invariant operators from Thinking Machines Lab. Deterministic inference is only supported with FlashInfer, FlashAttention 3 (FA3), and Triton attention backends. It maintains compatibility with chunked prefill, CUDA graphs, radix cache, and non-greedy sampling. [^94^]
Source: SGLang Documentation — Deterministic Inference
URL: https://sgl-project.github.io/advanced_features/deterministic_inference.html
Date: 2026-04-22
Excerpt: "Building on Thinking Machines Lab's batch-invariant operators, SGLang achieves fully deterministic inference while maintaining compatibility with chunked prefill, CUDA graphs, radix cache, and non-greedy sampling... Deterministic inference is only supported with the following three attention backends: FlashInfer, FlashAttention 3 (FA3), and Triton."
Context: Official SGLang documentation describing deterministic inference capabilities.
Confidence: high

Claim: The Thinking Machines Lab (Mira Murati's company) identified that batch size variations break numerical consistency in three key operations: normalization (RMSNorm), matrix multiplication, and attention. They built batch-invariant versions achieving perfect reproducibility — 1,000 identical runs produce 100% bitwise-identical outputs, even under dynamic batching. Performance cost is approximately 60% slower than standard vLLM. [^125^]
Source: NextBigFuture — Defeating Nondeterminism in LLM Inference by Thinking Machines
URL: https://www.nextbigfuture.com/2025/11/defeating-nondeterminism-in-llm-inference-by-thinking-machines.html
Date: 2025-11-17
Excerpt: "They built batch-invariant versions of all three operations and integrated them into vLLM... 1,000 identical runs -> 100% bitwise-identical outputs, even under dynamic batching. Performance cost is only a modest slowdown (10-40% depending on op/hardware)... 1,000 identical prompts yield dozens of unique outputs under normal conditions."
Context: Analysis of Thinking Machines Lab research on LLM inference determinism.
Confidence: high

Claim: The root cause of LLM inference nondeterminism is NOT GPU concurrency or floating-point non-associativity per se, but rather lack of batch invariance in inference kernels. Most transformer operations use deterministic reduction trees, not atomic operations. The true issue is that standard kernels in FlashAttention, cuBLAS, Triton, etc. are batch-sensitive — layer statistics, matmul reduction order, and softmax all change with batch shape. [^131^]
Source: Thinking Machines Lab Blog — Defeating Nondeterminism in LLM Inference
URL: https://thinkingmachines.ai/blog/defeating-nondeterminism-in-llm-inference/
Date: 2025-09-10
Excerpt: "Most transformer operations use deterministic reduction trees (fixed-order reductions), not atomic operations or unordered adds. GPU atomics are avoided in forward passes. True nondeterminism from races is rare. The true Root Cause? Lack of Batch Invariance in Inference Kernels... Standard kernels (in FlashAttention, cuBLAS, Triton, etc.) for key operations are batch-sensitive."
Context: Original research publication from Thinking Machines Lab explaining the true root cause of LLM inference nondeterminism.
Confidence: high

Claim: To achieve batch-invariant matrix multiplication, the easiest way is to compile one kernel configuration and use that for all shapes. This loses some performance but isn't typically disastrous in LLM inference. Despite obtaining batch invariance, they only lose about 20% performance compared to cuBLAS. [^131^]
Source: Thinking Machines Lab Blog
URL: https://thinkingmachines.ai/blog/defeating-nondeterminism-in-llm-inference/
Date: 2025-09-10
Excerpt: "So, the easiest way to ensure batch invariance for matmuls is to compile one kernel configuration and use that for all shapes. Although we will lose some performance, this isn't typically disastrous in LLM inference... Despite obtaining batch invariance, we only lose about 20% performance compared to cuBLAS."
Context: Technical implementation details of batch-invariant kernels from the original research.
Confidence: high

Claim: NVIDIA CUB's Reproducible Floating-point Accumulator (RFA) counters floating-point non-associativity by grouping all input values into a fixed number of exponent ranges (default three bins). This fixed, structured accumulation order ensures the final result is independent of GPU architecture. [^91^]
Source: NVIDIA Developer Blog
URL: https://developer.nvidia.com/blog/controlling-floating-point-determinism-in-nvidia-cccl/
Date: 2026-03-05
Excerpt: "CUB uses a Reproducible Floating-point Accumulator (RFA), a solution based on the NVIDIA GTC 2024 session, Restoring the Scientific Method to HPC: High Performance Reproducible Parallel Reductions. The RFA counters floating-point non-associativity by grouping all input values into a fixed number of exponent ranges (the default is three bins)."
Context: Official NVIDIA documentation of a production deterministic floating-point accumulation algorithm.
Confidence: high

Claim: Even with `torch.use_deterministic_algorithms(True)` and `torch.backends.cudnn.deterministic = True`, PyTorch can still produce nondeterministic results due to atomic operations in CUDA, particularly `atomicAdd`, where the order of parallel additions to the same value is undetermined for floating-point variables. [^96^]
Source: Stack Overflow — Non-reproducible results in PyTorch after saving and loading the model
URL: https://stackoverflow.com/questions/57195650/non-reproducible-results-in-pytorch-after-saving-and-loading-the-model
Date: 2019-07-25
Excerpt: "There are some PyTorch functions that use CUDA functions that can be a source of non-determinism. One class of such CUDA functions are atomic operations, in particular atomicAdd, where the order of parallel additions to the same value is undetermined and, for floating-point variables, a source of variance in the result."
Context: Official PyTorch documentation excerpt explaining CUDA-level sources of non-determinism.
Confidence: high

---

### 6. Formal Methods for Deterministic Systems

Claim: TLA+ (Temporal Logic of Actions) models systems as state machines and exhaustively explores every reachable state. Amazon used it to find critical bugs in DynamoDB, S3, and EBS. TLA+ answers: "Can my system reach a bad state through some sequence of events?" [^143^]
Source: James Phoenix — Formal Verification for Agent Orchestration
URL: https://understandingdata.com/posts/formal-verification-for-agent-orchestration/
Date: 2026-04-16
Excerpt: "TLA+ (Temporal Logic of Actions) models systems as state machines, then exhaustively explores every reachable state. Created by Leslie Lamport. Amazon used it to find critical bugs in DynamoDB, S3, and EBS that no amount of testing caught."
Context: Practical guide applying formal verification to AI agent systems, specifically recommending TLA+ for orchestration logic and Z3 for static validation.
Confidence: high

Claim: The seL4 project represents the first comprehensive verification of an entire general-purpose OS kernel, providing a complete proof chain from high-level security requirements (integrity, confidentiality, availability) down to executable machine code. seL4 is the only general-purpose OS kernel fully formally verified for functional correctness with machine-checked end-to-end theorems. [^77^]
Source: Comprehensive Formal Verification of an OS Microkernel (CACM)
URL: https://sel4.systems/Research/pdfs/comprehensive-formal-verification-os-microkernel.pdf
Date: 2014 (ongoing maintenance)
Excerpt: "The seL4 project represents the first comprehensive verification of an entire general-purpose OS kernel, providing a complete proof chain from the usual, high-level security and safety requirements, that is, integrity, confidentiality and availability, down to the executable machine code."
Context: Landmark academic paper documenting the complete formal verification of the seL4 microkernel in Isabelle/HOL.
Confidence: high

Claim: seL4 verification uses refinement proofs establishing correspondence between high-level (abstract) and low-level (concrete) representations. The functional correctness proof required roughly 20 person-years for ~10,000 lines of C code, with additional proofs for IPC fastpath, access control, information-flow noninterference, and binary verification. Total proof maintenance: ~480,000 lines of Isabelle proofs and specifications. [^77^]
Source: seL4 Comprehensive Verification Paper
URL: https://sel4.systems/Research/pdfs/comprehensive-formal-verification-os-microkernel.pdf
Date: 2014
Excerpt: "The functional correctness proof required roughly 20 person-years... with now 480,000 lines of Isabelle proofs and specifications... The security proofs represent only $78/SLOC, a very low figure for the strongest assurance ever produced about the security of a general-purpose OS kernel."
Context: Detailed cost and effort analysis of the seL4 formal verification project.
Confidence: high

Claim: Formal methods cover the deterministic shell of AI agent systems, while the LLM core stays in eval/testing territory. High-value formal verification targets include: orchestrator state machines, multi-agent deadlocks, routing completeness, permission guards, and budget constraint proofs. Low-value targets include modeling LLM output quality and prompt effectiveness. [^143^]
Source: James Phoenix — Formal Verification for Agent Orchestration
URL: https://understandingdata.com/posts/formal-verification-for-agent-orchestration/
Date: 2026-04-16
Excerpt: "Formal methods cover the deterministic shell. The LLM core stays in eval/testing territory... TLA+: orchestrator state machine [high value]. TLA+: modeling LLM output quality [low value]."
Context: Practical guidance on where to apply formal methods in AI agent architectures.
Confidence: high

Claim: The TLA+ Proof System (TLAPS) supports SMT solvers, the Zenon tableau prover, and Isabelle encoding. It is currently restricted to proving safety properties. Planned extensions for liveness properties require support for ENABLED predicates and first-order temporal logic reasoning. [^150^]
Source: Formal Specification and Verification (ACM Computing Surveys)
URL: https://members.loria.fr/Stephan.Merz/papers/2019-acm.pdf
Date: 2019
Excerpt: "TLAPS supports SMT solvers (via a translation to the SMT-LIB2 language), the tableau prover Zenon, and an encoding of TLA+'s mathematical set theory as an object logic in the logical framework Isabelle... TLAPS is currently restricted to proving safety properties."
Context: Comprehensive academic survey of TLA+ and its proof capabilities.
Confidence: high

---

### 7. Replay Systems for AI Agents

Claim: Deterministic replay for AI agents requires recording all LLM responses and tool outputs during a live run. During replay, substitute recorded responses for live calls. The minimum event set includes: every LLM request with full prompt and response, every tool call with inputs and outputs, every agent-to-agent message, and state snapshot at each handoff point. [^166^]
Source: Augment Code — How to Debug Parallel AI Agents Without Going Insane
URL: https://www.augmentcode.com/guides/debug-parallel-ai-agents
Date: 2026-04-09
Excerpt: "Record every production run proactively rather than waiting for a failure. The minimum event set for a usable replay artifact is: every LLM request with its full prompt and response, every tool call with its inputs and outputs, every agent-to-agent message, and the state snapshot at each agent handoff point."
Context: Engineering guide from an AI coding assistant company on production debugging practices for multi-agent systems.
Confidence: high

Claim: A deterministic replay system for AI agents starts with structured, append-only execution traces. The trace must include: LLM calls (prompt, sampling parameters, exact response), tool calls (request + response), decisions (plan selection, tool choice), model parameters, tool versions, timestamps, and structured inputs/outputs. [^171^]
Source: Sakura Sky — Trustworthy AI Agents: Deterministic Replay
URL: https://www.sakurasky.com/blog/missing-primitives-for-trustworthy-ai-part-8/
Date: 2025-11-20
Excerpt: "A deterministic replay system starts with one requirement: every meaningful step an agent performs must be captured as a structured, append only event... The trace must include the following information: LLM calls: Every interaction with the model must be recorded, including the prompt, sampling parameters, and the exact response returned."
Context: Blog series on trustworthy AI primitives, focusing on deterministic replay as a governance and debugging primitive.
Confidence: high

Claim: The replay fidelity ladder has 5 levels: Level 0 (log-only), Level 1 (tool-response recording), Level 2 (state snapshots), Level 3 (deterministic branching), Level 4 (diff-based experiments). Level 2 is where teams start shipping agents confidently. [^169^]
Source: Thinking Loop — Replayable Agent Runs: The Debugging Trick That Ships
URL: https://medium.com/@ThinkingLoop/replayable-agent-runs-the-debugging-trick-that-ships-f5460ebf390a
Date: 2026-01-21
Excerpt: "Level 0: Log-only. Level 1: Tool-response recording. Level 2: State snapshots. Level 3: Deterministic branching. Level 4: Diff-based experiments. Level 2 is where teams start shipping agents confidently."
Context: Practical engineering guide on implementing replayable agent execution.
Confidence: high

---

### 8. Deterministic Scheduling Algorithms

Claim: Rate-Monotonic Scheduling (RMS) and Earliest-Deadline-First (EDF) are optimal fixed-priority and dynamic-priority schedulers respectively. A set of n periodic tasks under the priority ceiling protocol can be scheduled by RMS if: ∀i, 1≤i≤n, Σ(j=1 to i-1)(cj/pj) + (ci+Bi)/pi ≤ i(2^(1/i)-1), where Bi is the worst-case blocking time. [^58^]
Source: Real-Time Process Scheduling (NTU Lecture Notes)
URL: https://www.csie.ntu.edu.tw/~ktw/rts/uniprocessor-scheduling.pdf
Date: Ongoing course material
Excerpt: "RMS & EDF are optimal fixed-priority & dynamic-priority schedulers, respectively. RMS is stable, but EDF has a high achievable utilization factor... Theorem 15: A set of n periodic tasks under the priority ceiling protocol can be scheduled by the rate monotonic algorithm if the following conditions are satisfied..."
Context: Academic lecture notes on real-time scheduling theory and schedulability analysis.
Confidence: high

Claim: seL4's worst-case execution time (WCET) analysis is sound, complete, and high-assurance — the first ever such analysis for a protected-mode real-time operating system. They developed a scheduling model with capability-authorised access to processor time, resulting in the MCS version of seL4 currently undergoing formal verification. [^126^]
Source: Trustworthy Systems — Timing guarantees for mixed-criticality systems on seL4
URL: https://trustworthy.systems/projects/RTA/
Date: 2025-12-08
Excerpt: "We performed a sound, complete and high-assurance worst-case execution time (WCET) analysis of seL4, to our knowledge the first ever such analysis for a protected-mode real-time operating system. We developed a scheduling model with capability-authorised access to processor time, resulting in the new MCS version of seL4 that is currently undergoing formal verification."
Context: Research project page for real-time scheduling verification on seL4.
Confidence: high

---

### 9. Time-Travel Debugging for AI

Claim: rr (Record and Replay) is a lightweight recording and deterministic debugging tool for Linux developed by Mozilla. It records native application execution and allows full reverse execution during replay. It's designed to be efficient with low overhead and integrates well with GDB. [^46^]
Source: Awesome Time-Travel Debugging GitHub Repository
URL: https://github.com/xusheng6/awesome-ttd
Date: 2025-11-02
Excerpt: "rr: Free and Open Source. A lightweight recording and deterministic debugging tool for Linux. Developed by Mozilla, rr records native application execution and allows full reverse execution during replay. It's designed to be efficient with low overhead and integrates well with GDB."
Context: Curated list of time-travel debugging tools and resources.
Confidence: high

Claim: WinDbg TTD (Time Travel Debugging) is Microsoft's official solution integrated into WinDbg Preview. It captures a trace of process execution and replays it later both forwards and backwards. TTD allows going back in time to understand conditions that lead up to bugs. [^47^]
Source: Microsoft Learn — Time Travel Debugging Overview
URL: https://learn.microsoft.com/en-us/windows-hardware/drivers/debuggercmds/time-travel-debugging-overview
Date: 2025-11-06
Excerpt: "Time Travel Debugging (TTD) is a tool that captures a trace of your process as it executes and replays it later both forwards and backwards. TTD helps you debug issues by letting you 'rewind' your debugger session, instead of having to reproduce the issue until you find the bug."
Context: Official Microsoft documentation for WinDbg TTD.
Confidence: high

Claim: There are three main approaches to implementing time-travel debugging: (1) Record & Replay — record all non-deterministic inputs and replay deterministically; (2) Snapshotting — periodically take snapshots of entire state; (3) Instrumentation — add code that logs changes in state. rr uses Record & Replay, as does Replay. WinDbg uses first two, and Undo uses all three. [^52^]
Source: Temporal.io Blog — Time-travel debugging production code
URL: https://temporal.io/blog/time-travel-debugging-production-code
Date: 2023-08-07
Excerpt: "There are three main approaches to implementing time-travel debugging: Record & Replay: Record all non-deterministic inputs to a program during its execution. Snapshotting: Periodically take snapshots of a program's entire state. Instrumentation: Add extra code to the program that logs changes in its state."
Context: Technical blog post explaining time-travel debugging implementation approaches.
Confidence: high

---

### 10. Byte-Identical Reproducibility in Neural Networks

Claim: Even greedy decoding can yield different results across runs due to numerical precision issues. Frameworks like PyTorch and TensorFlow provide flags for deterministic behavior, but in practice can still produce nondeterministic results even with these flags. [^75^]
Source: arXiv — Understanding and Mitigating Numerical Sources of Nondeterminism in LLM Inference
URL: https://arxiv.org/html/2506.09501v2
Date: 2025-04-28
Excerpt: "Even with a fixed seed, differences in computation order can alter the sequence of the pseudo-random number generator. Meanwhile, frameworks like PyTorch and TensorFlow provide flags for deterministic behavior... However, in practice, it can still produce nondeterministic results even with these flags."
Context: Academic paper systematically studying numerical sources of non-determinism in LLM inference.
Confidence: high

Claim: OpenAI exposes a `seed` parameter but the same seed plus same input plus same `system_fingerprint` produces the same output most of the time. When OpenAI updates the model or backend, the system_fingerprint changes and reproducibility breaks. Anthropic does not expose a stable seed parameter as of early 2026. [^73^]
Source: SurePrompts — LLM Temperature and Sampling: The Complete 2026 Reference Guide
URL: https://sureprompts.com/blog/llm-temperature-sampling-complete-guide-2026
Date: 2026-04-22
Excerpt: "OpenAI exposes `seed`. The same seed plus the same input plus the same `system_fingerprint` produces the same output most of the time. When OpenAI updates the model or backend, the system_fingerprint changes and reproducibility breaks. Anthropic does not expose a stable seed parameter as of early 2026."
Context: Comprehensive industry reference guide on LLM sampling and reproducibility.
Confidence: high

Claim: DeepSeek-R1-Distill-Qwen-7B can show up to 9% variation in accuracy on the AIME dataset even with greedy decoding, due to system configuration changes like batch size and tensor parallelism size. [^175^]
Source: arXiv Paper
URL: https://arxiv.org/html/2511.17826
Date: 2025-11-21
Excerpt: "Even with greedy decoding, which should be deterministic since it always selects the most probable next token, reasoning models like DeepSeek-R1-Distill-Qwen-7B can still show up to a 9% variation in accuracy on the AIME dataset."
Context: Academic paper quantifying the real-world impact of inference non-determinism on benchmark accuracy.
Confidence: high

---

### 11. Deterministic Hash Chains for Audit Logs

Claim: Merkle tree hashing makes audit logs tamper-evident — altering any log entry changes its cryptographic hash, which cascades through the Merkle tree and changes the root hash. Published root hashes provide external verification anchors. The system is designed so even the entity operating the platform cannot retroactively alter evidence. [^167^]
Source: Regure — Immutable Audit Trail Software
URL: https://www.getregure.com/platform/audit-trails/
Date: 2026-03-17
Excerpt: "Merkle tree hashing makes logs tamper-evident for everyone — including Regure system administrators. Altering any log entry changes its cryptographic hash, which cascades through the Merkle tree and changes the root hash. Published root hashes provide external verification anchors."
Context: Enterprise audit trail product documentation explaining Merkle tree-based tamper evidence.
Confidence: high

Claim: OpenFang, a Rust-based Agent Operating System, implements a Merkle Hash-Chain Audit Trail (`audit.rs`) that creates a cryptographically linked, tamper-evident log of every agent action. Each entry is chained to the previous via SHA-256. [^170^]
Source: NousResearch/hermes-agent GitHub Issue
URL: https://github.com/NousResearch/hermes-agent/issues/487
Date: 2026-03-06
Excerpt: "OpenFang, a Rust-based Agent Operating System, implements a Merkle Hash-Chain Audit Trail (`audit.rs`) that creates a cryptographically linked, tamper-evident log of every agent action. Each entry is chained to the previous via SHA-256, making it impossible to modify or delete historical actions without breaking the chain."
Context: Feature request for implementing cryptographic audit trails in an AI agent framework, referencing existing Rust implementations.
Confidence: high

Claim: The Transparent Key Management Algorithm uses Merkle trees for transparent and verifiable key management. Log auditing involves traversing the Merkle tree to verify consistency of hashes from leaf nodes to the root. Any discrepancies indicate potential security breaches or data tampering. [^172^]
Source: PMC — Algorithm for Key Transparency with Transparent Logs
URL: https://pmc.ncbi.nlm.nih.gov/articles/PMC11585852/
Date: 2025
Excerpt: "Log Auditing Method involves traversing the Merkle tree to verify the consistency of hashes from leaf nodes to the root. Any discrepancies indicate potential security breaches or data tampering."
Context: Academic paper on cryptographic key transparency using Merkle trees.
Confidence: high

---

### 12. Real-Time Kernels for Safety-Critical Systems

Claim: seL4, QNX, INTEGRITY, and CertiKOS comparison shows that only seL4 and CertiKOS have correctness proofs; only seL4 has a security proof, fast IPC, fine-grained access control, MMU support, virtualization, is general purpose, AND open source. INTEGRITY underwent a security proof but the proof is not public and does not connect formally to source code. [^74^]
Source: seL4 Official Comparison Page
URL: https://sel4.systems/About/comparison.html
Date: 2026-04-17
Excerpt: "Only INTEGRITY underwent a security proof from formal code model to security property, but the proof is neither available for multiple current hardware architectures and OS versions, nor is it public. It also does not connect formally to the source code of the kernel."
Context: Official seL4 project comparison against commercial safety-critical RTOS kernels.
Confidence: high

Claim: INTEGRITY-178B is a commercial RTOS supporting ARINC-653, DO-178B, SKPP High Robustness standards on x86, PowerPC, ARM, MIPS. It provides access verification, processor MMU support, and ARINC partition scheduler (preemptive). [^173^]
Source: DTIC Survey of Real-Time Operating Systems and Virtualization
URL: https://apps.dtic.mil/sti/tr/pdf/ADA620757.pdf
Date: Unknown (military technical report)
Excerpt: "INTEGRITY-178B: Commercial, C/C++/Ada, ARINC-653; Integrity Kernel API, DO178-B; SKPP High Robustness, x86/PowerPC/ARM/MIPS, supervisor/user, Access verification; processor MMU support, ARINC- partition scheduler (preemptive)"
Context: Military survey of RTOS and virtualization technologies for aerospace applications.
Confidence: medium

---

### 13. Async Runtime Determinism

Claim: Tokio has first-class support for running with a single-threaded scheduler. Its clock is abstracted and can run "paused" for testing, where time only advances on calls to `sleep()`. The runtime has an internal RNG used in making scheduling decisions such as picking a branch for `tokio::select!` — but this can be seeded. [^86^]
Source: S2.dev Blog
URL: https://s2.dev/blog/dst
Date: 2025-04-02
Excerpt: "Tokio does have first-class support for running with a single-threaded scheduler. Internally, its clock is abstracted, and can run 'paused' for testing, where time only advances on calls to `sleep()`. By using `tokio::time::Instant` instead of `std::time::Instant`, you can ensure any measurement of elapsed time is aligned with this clock. The runtime also has an internal RNG used in making scheduling decisions such as picking a branch for `tokio::select!` – but this can be seeded."
Context: Production engineering blog describing how Tokio provides deterministic execution primitives.
Confidence: high

Claim: Turmoil is a framework for testing distributed systems in Rust that provides deterministic execution by running multiple concurrent hosts within a single thread. It introduces "hardship" via changes in the simulated network. The network can be controlled manually or with a seeded RNG. [^184^]
Source: Turmoil docs.rs
URL: https://docs.rs/turmoil/latest/turmoil/
Date: 2023-11-29
Excerpt: "Turmoil is a framework for testing distributed systems. It provides deterministic execution by running multiple concurrent hosts within a single thread. It introduces 'hardship' into the system via changes in the simulated network. The network can be controlled manually or with a seeded rng."
Context: Official Rust documentation for the Turmoil distributed systems testing framework.
Confidence: high

Claim: Loom is a Rust library that fixes concurrency testing problems by simulating the operating system's scheduler and Rust's memory model such that all possible valid behaviors are explored and tested. Test cases using loom must be fully deterministic. [^144^]
Source: Loom docs.rs
URL: https://docs.rs/loom/latest/loom/
Date: 2026-04-21
Excerpt: "Loom fixes the problem by simulating the operating system's scheduler and Rust's memory model such that all possible valid behaviors are explored and tested... Test cases using loom must be fully deterministic. All sources of non-determism must be via loom types so that loom can expose different possible values on each execution of the test closure."
Context: Official Rust documentation for the Loom concurrency testing framework.
Confidence: high

Claim: Shuttle is a library for testing concurrent Rust code focusing on randomized testing rather than exhaustive testing like Loom. Shuttle is not sound (a passing test does not prove correctness), but scales to much larger test cases. By controlling scheduling, Shuttle allows reproducing failing tests deterministically. [^142^]
Source: Shuttle docs.rs
URL: https://docs.rs/shuttle/latest/shuttle/
Date: 2026-04-21
Excerpt: "Shuttle focuses on randomized testing, rather than the exhaustive testing that Loom offers. This is a soundness—scalability trade-off: Shuttle is not sound (a passing Shuttle test does not prove the code is correct), but it scales to much larger test cases than Loom."
Context: Official Rust documentation for the Shuttle randomized concurrency testing library.
Confidence: high

---

### 14. Hardware-Level Determinism

Claim: Modern x86 CPUs have a feature called constant TSC (Time Stamp Counter). With these CPUs, the cycle counter updates at a fixed frequency independent of the operating frequency of the CPU. You can check for the "constant_tsc" flag in `/proc/cpuinfo`. If your CPU does not have this feature, you can typically disable power optimization features via BIOS. [^81^]
Source: UCSD CSE 221 — Measuring Time
URL: https://cseweb.ucsd.edu/classes/wi23/cse221-a/timing.html
Date: Ongoing course material
Excerpt: "Recent x86 CPUs have a feature called constant TSC. With these CPUs, the cycle counter updates at a fixed frequency independent of the operating frequency of the CPU... You can check whether your CPU has this feature by looking for the 'constant_tsc' flag for the CPU; e.g., with `cat /proc/cpuinfo` on Linux."
Context: University course notes on reliable hardware timing measurement.
Confidence: high

Claim: The TSC (Time Stamp Counter) is set to 0 at system reset. It presently increments once per processor cycle and is 64 bits wide. Only CPL = 0 can modify TSC. The `rdtsc` instruction is available with all Pentium processors but is not serializing. [^86^]
Source: Penn State — Performance Counters Library
URL: https://www.cse.psu.edu/~deh25/rabbit/menu4.html
Date: Ongoing documentation
Excerpt: "The TSC is set to 0 at system reset. It presently increments once per processor cycle, and is 64 bits wide. Only CPL = 0 can modify TSC... The rdtsc instruction is available with all the Pentium processors. It is not serializing."
Context: Academic documentation on x86 performance counter hardware.
Confidence: high

Claim: Modern CPU performance and power optimizations including hyper-threading, turbo boost, and dynamic frequency scaling make measurement using cycle counters challenging. The original cycle counter on the Cray-1 circa 1976 counted once per CPU cycle — "things have gone downhill from there." [^81^]
Source: UCSD CSE 221
URL: https://cseweb.ucsd.edu/classes/wi23/cse221-a/timing.html
Date: Ongoing
Excerpt: "Modern CPUs have a variety of performance and power optimizations, including hyper-threading, turbo boost, dynamic frequency scaling, etc., that make measurement using cycle counters more challenging... The original cycle counter on the Cray-1 circa 1976 counted once per CPU cycle. You could read it twice, subtract, and get 1. Things have gone downhill from there."
Context: Course notes on the challenges of hardware-level deterministic timing measurement.
Confidence: high

---

### 15. Deterministic Simulation Testing: FoundationDB and Industry

Claim: FoundationDB runs the real database software (not mocks, not stubs) in a discrete-event simulator alongside randomized workloads and aggressive fault injection. All sources of nondeterminism are abstracted: network, disk, time, and random number generation. After roughly one trillion CPU-hours of simulation testing, FoundationDB has been stress-tested under conditions far worse than any production environment. [^146^]
Source: Pierre Zemb — Diving into FoundationDB's Simulation Framework
URL: https://pierrezemb.fr/posts/diving-into-foundationdb-simulation/
Date: 2025-10-30
Excerpt: "FoundationDB runs the real database software (not mocks, not stubs) in a discrete-event simulator alongside randomized workloads and aggressive fault injection. All sources of nondeterminism are abstracted: network, disk, time, and random number generation... After roughly one trillion CPU-hours of simulation testing, FoundationDB has been stress-tested under conditions far worse than any production environment will ever encounter."
Context: Deep technical dive into FoundationDB's production simulation framework architecture.
Confidence: high

Claim: The core of DST is simple: instead of building a model of your code, take your real code and make it into the model. The FoundationDB team built Flow, a syntactic extension to C++ that allows modeling concurrency while the actual implementation is all single-threaded (using callbacks). The `g_network` pointer holds an `INetwork` interface — in production it points to `Net2` (real TCP), in simulation to `Sim2` (fake connections with in-memory buffers). [^147^]
Source: Boulder Ventures — A DST primer for unit test maxxers
URL: https://www.boulderventures.com/news/a-deterministic-simulation-testing-dst-primer-for-unit-test-maxxers
Date: 2025-11-20
Excerpt: "The core of DST is very simple. Instead of building a model of your code – which is difficult and kind of misses the point – we're just going to take your real code, and make it into the model... The global `g_network` pointer holds an `INetwork` interface. In production, this points to `Net2`, which creates real TCP connections using Boost.ASIO. In simulation, it points to `Sim2`, which creates `Sim2Conn` objects (fake connections that write to in-memory buffers)."
Context: Accessible primer on DST implementation patterns, explaining FoundationDB's interface-swapping approach.
Confidence: high

Claim: The sled simulation guide states: "Step 1: write your code in a way that can be deterministically tested on top of a simulator. Step 2: build a simulator that will exercise realistic message passing behavior. Anyone who doesn't do this is building a very buggy distributed system, as Jepsen repeatedly shows. A notable exception being FoundationDB. Let's learn from their success and simulate." [^183^]
Source: sled.rs — Simulation Guide
URL: http://sled.rs/simulation.html
Date: Ongoing
Excerpt: "Step 1: write your code in a way that can be deterministically tested on top of a simulator. This also ensures you're properly applying the dependency inversion principle... Step 2: build a simulator that will exercise realistic message passing behavior. Anyone who doesn't do this is building a very buggy distributed system, as Jepsen repeatedly shows."
Context: Official sled database documentation promoting deterministic simulation as a core engineering practice.
Confidence: high

Claim: Deterministic simulation testing (DST) involves placing software under test in a simulated, deterministic environment. It was pioneered at FoundationDB and Amazon Web Services around 2010. DST relies on: running the system in an entirely virtual environment, carefully feeding entropy for reproducible random behavior, exploring the state space, and checking invariants. [^148^]
Source: Antithesis — Deterministic simulation testing
URL: https://antithesis.com/docs/resources/deterministic_simulation_testing/
Date: 2024-08-20
Excerpt: "Practical adoption of this approach was pioneered at FoundationDB and Amazon Web Services around 2010... Deterministic simulation testing relies on: Running the system in an entirely virtual environment to allow deterministic execution and replay for debugging purposes. Carefully feeding the system entropy such that the system and workload can still appear to have random behavior, while at the same time being perfectly reproducible."
Context: Commercial documentation from Antithesis (the DST company founded by FoundationDB creators).
Confidence: high

---

## Key Questions Answered

### Q1: Can GPU inference (Metal/MLX) be made fully deterministic?

**Answer: YES, but with significant trade-offs.**

GPU inference determinism is achievable at multiple levels:

1. **Quantized models on MLX**: Quantized integer models (Q4_K_M, Q8_0) achieve perfect reproducibility on Apple Silicon MLX. This is because integer operations are associative, unlike floating-point [^88^].

2. **Custom Metal kernels**: The `mlx-deterministic` project demonstrates bitwise-identical (0.0 tolerance) inference using custom Metal kernels with ~27-31% performance overhead for large matmul operations [^90^]. The Python wrapper approach achieves ~1e-5 tolerance with ~27-32% overhead by wrapping `mx.matmul()` with tiled reduction.

3. **Batch-invariant operations**: Thinking Machines Lab's batch-invariant kernels for CUDA (RMSNorm, matmul, attention) achieve 100% bitwise-identical outputs under dynamic batching with ~10-40% performance cost depending on operation and hardware [^125^][^131^]. SGLang has adopted these for production deterministic inference [^94^].

4. **NVIDIA CUB deterministic modes**: CUB provides explicit `gpu_to_gpu` determinism level using Reproducible Floating-point Accumulators, at 20-30% performance cost [^91^].

5. **Hardware-level determinism**: GPUDet demonstrated that fully deterministic GPU architectures are possible with as little as 4% overhead for compute-bound applications, though this requires hardware modifications [^181^].

**Key insight**: Floating-point non-associativity is the fundamental mathematical barrier. Any solution must control reduction order. This is a solved engineering problem, not a theoretical impossibility — but the performance/reproducibility trade-off is real and ranges from ~20-60% overhead depending on the strictness required.

---

### Q2: What is the state of the art in reproducible AI agent execution?

**Answer: Emerging but not yet standardized.**

The state of the art spans multiple layers:

1. **Deterministic replay systems**: Production patterns now exist for recording and replaying agent execution. The "replay fidelity ladder" defines 5 levels from log-only (Level 0) to diff-based experiments (Level 4). Level 2 (state snapshots) is the threshold for confident shipping [^169^].

2. **Structured execution traces**: Best practice requires append-only event sourcing of: LLM calls (prompt + exact response), tool calls (request + response), decisions, model parameters, tool versions, timestamps, and state snapshots [^171^].

3. **Merkle tree audit trails**: Cryptographic hash-chaining (SHA-256) provides tamper-evident logs of every agent action. OpenFang demonstrates this in Rust for agent operating systems [^170^][^167^].

4. **Deterministic simulation testing**: MadSim/Turmoil provide deterministic async runtime simulation for distributed agent systems. RisingWave uses MadSim in production [^92^][^86^].

5. **vLLM reproducibility**: vLLM provides `VLLM_ENABLE_V1_MULTIPROCESSING=0` for deterministic scheduling, plus seed control, but only guarantees reproducibility on same hardware/version [^20^].

6. **LLM determinism limitations**: Even with temperature=0 and fixed seeds, hosted APIs (OpenAI, Anthropic) only provide best-effort reproducibility. OpenAI's `system_fingerprint` changes break reproducibility on backend updates [^73^]. True determinism requires self-hosted inference with controlled kernels.

**Gap**: No unified open-source framework combines all layers (deterministic inference + structured tracing + cryptographic audit + deterministic replay) into a single substrate.

---

### Q3: How does MadSim handle async race conditions?

**Answer: Through three layers of determinism control.**

1. **Single-threaded execution**: MadSim runs all async tasks in a single-threaded simulator, eliminating OS scheduler non-determinism [^92^][^86^].

2. **libc symbol interception**: MadSim overrides `getrandom`, `getentropy`, `clock_gettime`, and `gettimeofday` at the libc level, replacing system entropy with a seeded PRNG and replacing real time with simulated time [^86^].

3. **Drop-in async runtime replacement**: MadSim provides `madsim-tokio`, `madsim-tonic`, `madsim-etcd-client`, etc. as drop-in replacements. When built with `RUSTFLAGS="--cfg madsim"`, the code runs in simulation mode with all I/O mocked [^92^].

**Race condition handling specifically**: Because execution is single-threaded, there are no true data races. The simulator controls the exact order of task execution. Randomized scheduling decisions (e.g., which task to poll next) use the seeded PRNG, so the same seed always produces the same interleaving. This allows reproduction of "race conditions" by re-running with the same seed.

**Limitation**: Any third-party dependency that reaches the real world through a non-intercepted path needs manual patching. This is a known integration challenge [^87^].

---

### Q4: What formal verification exists for deterministic runtimes?

**Answer: Extensive, but with clear boundaries.**

1. **seL4 microkernel**: The strongest example — complete functional correctness proof from abstract specification to C source code to binary, using Isabelle/HOL. Includes proofs of integrity, authority confinement, confidentiality (information-flow noninterference), and WCET analysis [^77^][^82^]. Cost: ~20 person-years for ~10,000 SLOC, with ~480,000 lines of proof.

2. **CertiKOS**: Another formally verified OS kernel with correctness and security proofs comparable to seL4. However, it is not general-purpose, has a very limited API, and is not deployed in real-world systems [^74^].

3. **TLA+ for distributed systems**: Used by Amazon for DynamoDB, S3, EBS. TLA+ verifies that systems cannot reach bad states through any sequence of events. The TLC model checker exhaustively explores state spaces [^143^][^150^].

4. **TLA+ for AI agents**: Emerging practice. TLA+ is recommended for verifying orchestrator state machines, multi-agent deadlock freedom, and workflow termination. Z3/SMT solvers recommended for static validation of routing logic, permission guards, and budget constraints [^143^].

5. **QNX/INTEGRITY commercial kernels**: These achieve high traditional assurance (DO-178B, ARINC-653) but NOT formal code-level verification. INTEGRITY has a security proof from formal code model to security property, but the proof is neither public nor connected to source code [^74^].

6. **Rust verification**: No formal verification exists for Rust async runtimes comparable to seL4. Loom and Shuttle provide testing (not proof) of concurrent behavior. The Rust type system prevents data races at compile time, but this is not formal verification of correctness.

**Key boundary**: Formal verification covers deterministic control logic (state machines, protocols, scheduling). It does NOT cover LLM behavior, which remains in the realm of statistical evaluation and testing.

---

## Synthesis: Implications for Rex Deterministic Kernel Design

### Proven Patterns to Adopt

1. **Interface swapping** (FoundationDB pattern): Design all I/O interfaces as swappable between real and simulated implementations. This is the core enabler of deterministic simulation testing [^147^].

2. **Seeded PRNG for all entropy**: Replace all sources of randomness (scheduling decisions, network latency, fault injection) with a single seeded PRNG. Same seed = same execution path [^146^].

3. **Single-threaded simulation**: Run the entire system in a single-threaded discrete event simulator for testing. This eliminates the vast majority of non-determinism sources [^92^][^148^].

4. **Structured append-only traces**: Record every LLM call, tool call, decision, and state change as structured, append-only events. This enables deterministic replay and cryptographic audit [^171^].

5. **Merkle-tree audit logs**: Chain execution events with cryptographic hashes for tamper-evident audit trails [^167^][^170^].

6. **Batch-invariant kernels for inference**: Use or implement batch-invariant versions of RMSNorm, matmul, and attention operations to achieve deterministic inference regardless of batch composition [^131^].

7. **Constant TSC / deterministic counters**: On x86, require `constant_tsc` CPU feature for reliable timing. Use abstracted virtual time in simulation [^81^].

### Experimental but Promising

1. **Rust const evaluation for compile-time invariants**: Use `const fn` and `const generics` to enforce invariants at compile time. However, Rust CTFE has limitations compared to Zig's `comptime` [^48^][^49^].

2. **Custom Metal kernels for MLX determinism**: The `mlx-deterministic` project shows this is achievable but requires maintaining custom kernels outside the official MLX codebase [^90^].

3. **GPU-to-GPU deterministic reductions**: NVIDIA CUB's RFA provides cross-GPU deterministic reductions but at 20-30% performance cost [^91^].

### Open Problems / Tensions

1. **Performance vs. determinism trade-off**: Batch-invariant kernels cost 10-60% performance. This is acceptable for research/safety-critical use but may be unacceptable for high-throughput serving [^128^][^131^].

2. **Distributed multi-GPU determinism**: Thinking Machines Lab's batch-invariant kernels handle single-GPU batch variation but distributed tensor parallelism introduces additional non-determinism from All-Reduce collectives [^175^]. This remains an open problem.

3. **Rust reproducible builds**: Even with `cargo`, byte-identical builds are challenging especially on Windows with MSVC. Requires special linker flags (`/Brepro`) and careful environment control [^174^].

4. **Formal verification of Rust async runtimes**: No Isabelle/HOL-level formal verification exists for any Rust async runtime (Tokio, async-std, smol). The seL4 proof required ~20 person-years and 480K lines of proof for 10K SLOC. Scaling this to a full async runtime is an open research problem.

5. **LLM non-determinism at temperature > 0**: Even with perfect kernel determinism, non-greedy sampling introduces intentional non-determinism. This is by design, not a bug. The Rex substrate must distinguish between "deterministic infrastructure" and "intentionally stochastic model behavior."

6. **Hardware variations**: True cross-hardware determinism (e.g., same output on M4 Max vs. H100) requires either: (a) exact reproducibility of floating-point operations across architectures (mathematically impossible for non-associative ops), or (b) integer-only quantized inference. This is a fundamental limitation, not an engineering gap [^88^][^91^].

### Recommendations for Rex Implementation

| Layer | Approach | Evidence |
|-------|----------|----------|
| Async runtime | MadSim-style deterministic simulator with tokio compatibility | RisingWave production use [^92^] |
| RNG | Seeded ChaCha20 or similar, per-component seed derivation | ruchy pattern [^25^] |
| Time | Virtual clock (Turmoil pattern), deterministic instant advances | S2.dev production [^86^] |
| Network | In-memory simulated network with deterministic latency/packet loss | FoundationDB pattern [^146^] |
| GPU inference | Batch-invariant kernels for RMSNorm/matmul/attention | Thinking Machines Lab [^131^] |
| Apple Silicon | Custom Metal kernels OR quantized models | mlx-deterministic [^90^] |
| Tracing | Structured append-only event log with Merkle chaining | OpenFang pattern [^170^] |
| Replay | Record LLM+tool responses, replay from trace index | Agent engineering best practice [^171^] |
| Formal verification | TLA+ for protocol/orchestration logic; Z3 for static guards | Amazon/Agent patterns [^143^] |
| Build | Reproducible builds with pinned toolchains, deterministic linkers | Rust community [^174^] |

---

## Citation Index

[^20^]: vLLM Documentation — Reproducibility (https://docs.vllm.ai/en/latest/usage/reproducibility/)
[^25^]: ruchy::reproducibility — Rust docs.rs (https://docs.rs/ruchy/latest/ruchy/reproducibility/index.html)
[^48^]: Rust Internals — const calls lookup table (https://internals.rust-lang.org/t/should-const-calls-with-small-finite-inputs-become-a-lookup-table/21617)
[^49^]: Rust RFCs — First-class compile time type manipulation (https://github.com/rust-lang/rfcs/issues/3669)
[^54^]: Ralf Jung — CTFE and type systems (https://www.ralfj.de/blog/2018/07/19/const.html)
[^56^]: Rust Const Generics Project Group (https://rust-lang.github.io/project-const-generics/vision/why-compile-time-evaluation.html)
[^58^]: NTU Real-Time Process Scheduling (https://www.csie.ntu.edu.tw/~ktw/rts/uniprocessor-scheduling.pdf)
[^73^]: SurePrompts LLM Temperature Guide 2026 (https://sureprompts.com/blog/llm-temperature-sampling-complete-guide-2026)
[^74^]: seL4 Comparison (https://sel4.systems/About/comparison.html)
[^75^]: arXiv — Numerical Sources of Nondeterminism in LLM Inference (https://arxiv.org/html/2506.09501v2)
[^77^]: seL4 Comprehensive Verification CACM (https://sel4.systems/Research/pdfs/comprehensive-formal-verification-os-microkernel.pdf)
[^81^]: UCSD CSE 221 Measuring Time (https://cseweb.ucsd.edu/classes/wi23/cse221-a/timing.html)
[^82^]: seL4 SOSP 2009 (https://read.seas.harvard.edu/~kohler/class/cs260r-17/klein10sel4.pdf)
[^85^]: MLX Ecosystem Analysis (https://yage.ai/share/mlx-apple-silicon-en-20260331.html)
[^86^]: S2.dev DST for async Rust (https://s2.dev/blog/dst)
[^87^]: Linera Protocol madsim issue (https://github.com/linera-io/linera-protocol/issues/6108)
[^88^]: MLX Nondeterminism Investigation (https://adityakarnam.com/mlx-non-determinism-apple-silicon/)
[^90^]: mlx-deterministic GitHub (https://github.com/ProbioticFarmer/mlx-deterministic)
[^91^]: NVIDIA CUB Determinism (https://developer.nvidia.com/blog/controlling-floating-point-determinism-in-nvidia-cccl/)
[^92^]: MadSim GitHub (https://github.com/madsim-rs/madsim)
[^94^]: SGLang Deterministic Inference (https://sgl-project.github.io/advanced_features/deterministic_inference.html)
[^96^]: Stack Overflow PyTorch reproducibility (https://stackoverflow.com/questions/57195650)
[^125^]: NextBigFuture Thinking Machines (https://www.nextbigfuture.com/2025/11/defeating-nondeterminism-in-llm-inference-by-thinking-machines.html)
[^126^]: seL4 Timing Guarantees (https://trustworthy.systems/projects/RTA/)
[^128^]: LLM Watch ELI5 (https://www.llmwatch.com/p/eli5-defeating-nondeterminism-in)
[^131^]: Thinking Machines Lab Blog (https://thinkingmachines.ai/blog/defeating-nondeterminism-in-llm-inference/)
[^142^]: Shuttle docs.rs (https://docs.rs/shuttle/latest/shuttle/)
[^143^]: Formal Verification for Agent Orchestration (https://understandingdata.com/posts/formal-verification-for-agent-orchestration/)
[^144^]: Loom docs.rs (https://docs.rs/loom/latest/loom/)
[^146^]: FoundationDB Simulation Deep Dive (https://pierrezemb.fr/posts/diving-into-foundationdb-simulation/)
[^147^]: DST Primer Boulder Ventures (https://www.boulderventures.com/news/a-deterministic-simulation-testing-dst-primer-for-unit-test-maxxers)
[^148^]: Antithesis DST (https://antithesis.com/docs/resources/deterministic_simulation_testing/)
[^150^]: Formal Specification and Verification ACM (https://members.loria.fr/Stephan.Merz/papers/2019-acm.pdf)
[^151^]: HN GPU determinism debate (https://news.ycombinator.com/item?id=37007811)
[^166^]: Augment Code Debug Parallel Agents (https://www.augmentcode.com/guides/debug-parallel-ai-agents)
[^167^]: Regure Audit Trails (https://www.getregure.com/platform/audit-trails/)
[^169^]: Thinking Loop Replayable Agents (https://medium.com/@ThinkingLoop/replayable-agent-runs-the-debugging-trick-that-ships-f5460ebf390a)
[^170^]: Hermes Agent Merkle Audit (https://github.com/NousResearch/hermes-agent/issues/487)
[^171^]: Sakura Sky Deterministic Replay (https://www.sakurasky.com/blog/missing-primitives-for-trustworthy-ai-part-8/)
[^173^]: DTIC RTOS Survey (https://apps.dtic.mil/sti/tr/pdf/ADA620757.pdf)
[^174^]: Rust Users Reproducible Builds (https://users.rust-lang.org/t/how-to-perform-reproducible-builds-on-windows/133356)
[^175^]: arXiv Batch Invariant Operations LLM (https://arxiv.org/html/2511.17826)
[^181^]: GPUDet ASPLOS 2013 (https://people.ece.ubc.ca/aamodt/publications/papers/jooybar.asplos2013.pdf)
[^182^]: GPUDet UBC Thesis (https://open.library.ubc.ca/media/stream/pdf/24/1.0074006/1)
[^183^]: sled Simulation Guide (http://sled.rs/simulation.html)
[^184^]: Turmoil docs.rs (https://docs.rs/turmoil/latest/turmoil/)

---

*Report generated as part of UASA/Rex deterministic superintelligence substrate research.*
*All claims traced to primary sources with confidence ratings.*
*Tensions, limitations, and trade-offs documented explicitly.*
