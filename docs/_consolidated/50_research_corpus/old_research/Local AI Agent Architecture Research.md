# **Epistemos Omega: Architecting a Local-First, Hybrid-SSM Cognitive Operating System for macOS**

## **Executive Summary**

The transition from cloud-dependent generative models to local-first, agentic cognitive operating systems represents a critical frontier in artificial intelligence research and commercial deployment. The objective of Epistemos Omega is to transform Apple Silicon computing environments into private, Artificial General Intelligence (AGI)-grade workstations. Accomplishing this requires a synthesis of highly optimized local language models, deeply integrated macOS automation frameworks, and an autoresearch-driven self-improvement loop.

Extensive architectural evaluation reveals that a pure State Space Model (SSM) architecture, such as Mamba-2, while theoretically optimal for infinite-context linear processing and reduced memory overhead, suffers from inherent "reasoning drift" and strict formatting degradation when executing complex, multi-turn JSON tool calls.1 Therefore, the optimal foundation for the Epistemos Omega cognitive engine is a Hybrid Mamba-Attention architecture. Utilizing a progressive distillation methodology inspired by the Mamba-in-Llama configuration, the model will leverage Mamba layers for sequence efficiency and periodic Attention layers as global memory anchors to ensure precise structured output generation.1

The system architecture must be bifurcated across a rigorous Rust and Swift Foreign Function Interface (FFI) boundary. Rust is the superior choice for state management, continuous agent orchestration, and the Model Context Protocol (MCP) server, capitalizing on strict memory safety, asynchronous execution models, and robust zero-cost abstractions.3 Swift must be utilized exclusively to handle the Machine Learning eXploration (MLX) inference execution, ScreenCaptureKit integration, and native UI elements, bridging asynchronous FFI calls via UniFFI or the highly optimized BoltFFI framework.4

To definitively surpass cloud capabilities in desktop automation, the perception layer must prioritize the native macOS Accessibility (AX) tree via the accessibility-sys crate. Because research indicates that only 33% to 36% of macOS applications provide complete, high-quality native accessibility metadata, the system must integrate a real-time Vision-Language Model (VLM) fallback.6 Modeled after the Screen2AX framework, this fallback will reconstruct hierarchical UI structures from raw pixels, translating visual data into actionable accessibility graphs for the orchestrator.6

The developmental sequence is paramount: the Rust/Swift infrastructure and MCP tool registries must be engineered prior to model distillation. This infrastructure will utilize a frontier cloud model to generate high-fidelity synthetic training traces.7 These traces will subsequently fuel the Oriented Distillation for Inline Acceleration (ODIA) and Parallel-Agent Reinforcement Learning (PARL) pipelines to fine-tune the 1B–8B parameter local hybrid models.8 The analysis that follows details the precise architectural blueprints, training recipes, and implementation roadmaps required to successfully instantiate this autonomous operating system.

## ---

**Section 1: Model Architecture for Agentic Performance**

## **1.1 Mamba/SSM Models for Tool Use and Agentic Reasoning**

State Space Models (SSMs), particularly the Mamba-2 architecture, offer linear time inference complexity and a constant memory footprint, characteristics that are highly attractive for local execution on resource-constrained edge hardware like Apple Silicon.10 However, empirical evaluations demonstrate that pure SSM architectures exhibit distinct failure modes when deployed in complex agentic scenarios. While pure Mamba models excel at continuous sequence processing and long-context summarization, they fundamentally struggle with the "copying mechanism" and the long-range exact recall required for strict JSON schema adherence, nested tool-call execution, and dynamic multi-step logic.1

NVIDIA's Nemotron 3 Super provides a definitive architectural template for overcoming these limitations. Functioning as a 120-billion-parameter open model with only 12 billion active parameters per forward pass, Nemotron 3 Super employs a Latent Mixture-of-Experts (LatentMoE) Hybrid Mamba-Transformer architecture.1 By interleaving Mamba-2 layers with periodic Self-Attention layers, the architecture retains the inference speed of SSMs while utilizing the attention layers as "global anchors" for exact token retrieval.1 Furthermore, Nemotron 3 Super incorporates Multi-Token Prediction (MTP) with shared-weight heads. This design stabilizes autoregressive drafting, dramatically improves training signals for structured outputs, and enables built-in speculative decoding for a 2x to 3x wall-clock speedup.16

In the realm of smaller models, the Mamba-in-Llama distillation approach demonstrates that retaining approximately 25% of a Transformer's attention layers while converting the remaining 75% to Mamba yields a model that preserves precise tool-calling capabilities while drastically reducing inference latency.2 Alternatively, Mistral's Codestral Mamba (7B), which is heavily optimized for code generation, frequently requires structural guardrails (e.g., forced JSON schema constraints during decoding) to prevent formatting drift in deep nested tool chains, highlighting the inherent fragility of pure SSMs in rigorous syntax environments.11

The architectural recommendation for Epistemos Omega's custom models (1B/3B/8B) is a **Hybrid Mamba-Attention** architecture. A pure Mamba-2 model will fail at deterministic macOS tool execution. The models must be distilled from a robust Transformer teacher using the MOHAWK progressive distillation pipeline, maintaining a minimum 3:1 ratio of Mamba to Attention layers.10 This preserves the linear processing advantages on the MLX framework while retaining the strict copying capabilities required for zero-shot JSON tool execution.

## **1.2 Training Small Models Specifically for Tool Calling**

Training Small Language Models (SLMs) to execute complex agentic workflows requires highly specialized post-training recipes. General instruction tuning is insufficient for autonomous operating systems.

The Oriented Distillation for Inline Acceleration (ODIA) framework proves that small models can be distilled using online user interaction data to successfully handle complex function calls.8 ODIA methodology focuses on automatically identifying "simple queries" from production traffic and distilling those specific execution patterns into SLMs. This approach has demonstrated a median latency reduction of 78% in production environments while maintaining the accuracy of the larger teacher models.8

To enable parallel multi-agent workflows on a local machine, the training data must incorporate Parallel-Agent Reinforcement Learning (PARL) mechanisms, a paradigm pioneered by Moonshot AI in the development of Kimi K2.5.9 PARL explicitly combats "serial collapse"—the tendency of multi-agent systems to default to slow, single-threaded operations despite having parallel computational capacity. PARL utilizes staged reward shaping: an early "instantiation reward" incentivizes the model to spawn concurrent sub-agents, while later training phases penalize critical path latency, forcing the model to allocate work across sub-agents in a way that minimizes end-to-end execution time.9

To maximize tool-calling efficacy, the training data composition for the local hybrid model should be structured as follows:

| Data Category | Percentage | Rationale |
| :---- | :---- | :---- |
| **General Language & Code** | 20% | Maintains semantic fluency, programmatic logic, and prevents catastrophic forgetting of broad world knowledge.10 |
| **Synthetic Tool-Call Examples** | 40% | High-fidelity synthetic datasets distilled from frontier models executing exact macOS-specific schemas via the ODIA methodology.7 |
| **Multi-Step Reasoning Traces** | 20% | Chain-of-thought trajectories that explicitly penalize "reasoning drift" and reward logical consistency over long contexts.1 |
| **macOS-Specific Automation** | 20% | Curated datasets of AppleScript, JXA (JavaScript for Automation), and structured Accessibility Tree JSON responses mapped to deterministic UI interactions.23 |

## **1.3 Sequencing: Build Models First or Build Agent Infrastructure First?**

The interdependencies of machine learning systems dictate that the programmatic infrastructure must precede the local model training. The proven development path involves building the Rust+Swift agent infrastructure first, utilizing a high-capability cloud-based frontier model (e.g., Claude 3.5 Sonnet API) as a temporary orchestration engine.

This sequencing enables the infrastructure to act as a high-fidelity synthetic data generator.7 By operating the macOS application via a cloud model, the system logs thousands of successful, verified macOS interaction trajectories. The exact Model Context Protocol (MCP) tool schemas and real-world execution traces then formulate the dataset for the ODIA distillation pipeline.8 Training the custom Mamba-hybrid model directly on the specific MCP tool schemas present in Epistemos Omega bakes the application's unique toolset into the model's parametric memory. This base-model integration dramatically outperforms generic LoRA adapter approaches in zero-shot tool accuracy. Hot-swappable Reinforcement Learning from AI Feedback (RLAIF) adapters can later be applied specifically for user workflow personalization rather than foundational tool comprehension.25

## ---

**Section 2: The Optimal Agent Architecture on macOS**

## **2.1 Hybrid Rust+Swift Stack for Agent Orchestration**

Achieving absolute minimum latency, robust state management, and maximum reliability on macOS necessitates a meticulously designed bi-lingual architecture. Swift is non-negotiable for interfacing with low-level Apple frameworks. Specifically, ScreenCaptureKit for high-performance frame buffering, App Intents for application integration, and the MLX framework for hardware-accelerated tensor operations on Apple Silicon demand native Swift implementation.26 However, Swift struggles with complex, cross-platform asynchronous state management and lacks the extensive ecosystem of open-source agentic tooling available in Rust.

Rust serves as the optimal language for the application's core logic, MCP server execution, SQLite state management, and multi-agent orchestration.3 Existing open-source architectures validate this division of labor. Screenpipe effectively utilizes a Rust core connected to macOS APIs via the accessibility-sys crate, capturing screen data and managing an event-driven SQLite database, while exposing a Model Context Protocol server.29 Conversely, Ghost OS relies entirely on Swift, wrapping the AXUIElement framework via AXorcist.31

The critical bridging technology required for this hybrid stack is a Foreign Function Interface (FFI) layer. Mozilla's uniffi-rs is the standard for generating Swift bindings from Rust code. The FFI boundary must strictly separate state from execution. Rust should manage the asynchronous task pool, maintain the tool registry, and issue requests to the Swift layer. Because uniffi supports asynchronous future conversion between Rust and Swift, the system can seamlessly stream token outputs from the MLX framework in Swift back to the Rust orchestrator.4 To prevent resource leaks, the architecture must implement UniFFI's ForeignFutureDroppedCallback to ensure that if a Swift UI task is cancelled or fails, the underlying Rust future is properly dropped and memory is freed.33 Furthermore, emerging tools like BoltFFI present a highly compelling alternative, demonstrating up to 1000x lower overhead compared to UniFFI in primitive passing microbenchmarks, which is critical for the microsecond latencies required in continuous agentic loops.5

## **2.2 Accessibility Tree vs Screenshots vs Hybrid for Computer Use**

The dichotomy between screenshot-based vision agents and native structured data access defines the reliability and speed of desktop automation. Visual and screenshot-based agents, such as Anthropic's initial Computer Use iterations, suffer from high latency, high token consumption, and brittle pixel-coordinate interaction logic.34 Ghost OS successfully utilizes the macOS Accessibility API to read structured UI elements directly, translating them into lightweight, semantic JSON context.31

However, reliance strictly on native Accessibility APIs introduces a critical failure mode. Empirical studies conducted for the Screen2AX framework demonstrate that only 33% to 36% of macOS applications offer complete, high-quality accessibility metadata. Conversely, 46% include only partial metadata, and 18% lack accessibility support entirely.6

The definitive solution for Epistemos Omega is a **Hybrid Perception Pipeline**. The primary data ingestion route must utilize the Rust accessibility-sys crate to capture the exact UI hierarchy in real-time.29 If the accessibility tree returns sparse or non-actionable data (frequently observed in Electron apps, video games, or custom-rendered UIs), the system immediately falls back to a visual approach. Utilizing the *Screen2AX* methodology, a local lightweight Vision-Language Model interprets the raw screen pixels captured via ScreenCaptureKit and synthetically reconstructs the missing hierarchical accessibility tree as a structured JSON object.6 The Screen2AX approach has demonstrated a 77% F1 score in tree reconstruction and a 2.2x performance improvement over native representations on the ScreenSpot task execution benchmark.6

## **2.3 Tool Design for Maximum Agent Performance**

Agent-friendly tools must minimize the cognitive load and "thinking tax" on the underlying language model.36 Rather than exposing granular, atomic actions (e.g., mouse\_move, mouse\_click\_x\_y, type\_char), which force the model into error-prone, multi-step loops, tools must be coarse-grained and state-aware.

Ghost OS establishes a highly effective "recipe" system.31 A recipe is a parameterized JSON macro representing a successful, multi-step workflow synthesized by a larger model during a learning phase. For Epistemos Omega, tools should feature explicit chain-of-thought hints within their schema descriptions (e.g., *"Use execute\_recipe for repetitive folder navigations before falling back to manual ax\_click"*).

Robust error handling is paramount for autonomous operation. Tools must not simply fail; they must return explicit, structured error messages containing the current UI state to allow the LLM to self-correct. When an LLM executes an action, the tool must temporarily halt, poll the AX tree to confirm state mutation, and return the state differential to the model. This ensures a tightly coupled plan-execute-verify loop, preventing the agent from hallucinating rapid successions of invalid actions.

## ---

**Section 3: Making Local Models Beat Cloud Models**

## **3.1 Where Local Models Have Structural Advantages**

A specialized 3B–8B local model running on Apple Silicon via the MLX framework possesses distinct structural advantages over 100-billion-parameter cloud models across several operational vectors:

| Advantage | Mechanism | User Experience Impact |
| :---- | :---- | :---- |
| **Latency** | Network transit imposes a hard floor of 500ms to 2 seconds on cloud APIs. A local MLX model on an Apple Silicon Neural Engine generates time-to-first-token (TTFT) in sub-50 milliseconds.26 | Enables real-time "ghost text" inline completions, fluid terminal control, and continuous ambient observation without UI stutter. |
| **Context Depth** | Cloud models are constrained by API costs and token payload sizes. A local model operates with a theoretically infinite stream of data via continuous processing. | The model can silently ingest the user's entire clipboard history, file system metadata, and continuous ScreenCaptureKit frames without cost.29 |
| **Privacy** | 100% on-device execution.29 | Enables the processing of highly sensitive workflows (medical records, legal discovery, proprietary corporate codebases) that legally cannot be transmitted to external servers.37 |
| **Personalization** | MLX supports highly efficient on-device LoRA training.38 | The model continually internalizes the user's exact writing cadence, folder structures, and daily automation routines, creating a tailored cognitive environment.39 |

## **3.2 Where Cloud Models Still Win (and How to Close the Gap)**

Despite the advantages of edge computing, frontier cloud models retain superiority in raw reasoning and zero-shot problem-solving. A 200B+ parameter model inherently possesses broader world knowledge and stronger reasoning capabilities on out-of-distribution tasks.

To close this gap, Epistemos Omega must rely on deep system integration rather than parameter count. By providing the local model with robust Retrieval-Augmented Generation (RAG) capabilities connected to the user's local Obsidian vaults, Apple Notes, Mail archives, and a designated Web Search MCP tool, the model grounds its reasoning in explicit data rather than relying on internal parametric memory.40 Furthermore, while cloud models excel at complex multimodal synthesis, Epistemos Omega mitigates this by routing high-complexity visual tasks to the specialized Screen2AX VLM adapter, reserving the core language model strictly for semantic and logical orchestration.6

## **3.3 The "Runner H" Precedent**

The viability of small models dominating complex agentic tasks is heavily supported by H Company's "Runner H" platform. Using a highly specialized 3-billion-parameter Vision-Language Model named Holo-1, Runner H achieved a 67% task completion success rate on the complex WebVoyager benchmark, significantly outperforming Anthropic's much larger Computer Use model, which achieved only 52%.34

The architecture of Runner H proves that when a small model is meticulously fine-tuned for a narrow, UI-grounded objective—such as predicting exact X, Y coordinates and interpreting nested UI trees—it can outperform generalized cloud models that are burdened by high "thinking taxes" and generalized context drift.34 Holo-1's training on the proprietary WebClick dataset, which contains dense, click-level annotations of complex web interfaces, allowed it to achieve Pareto-optimal performance.34 This provides definitive evidence that a specialized 3B-8B local model, trained on high-fidelity macOS automation traces, can consistently beat general-purpose cloud models on desktop automation tasks.

## ---

**Section 4: The Complete System Design**

## **4.1 Integration Architecture Blueprint**

The integration architecture of Epistemos Omega merges high-performance Rust systems programming with Apple-native Swift frameworks, orchestrated across five distinct layers.

\[Layer 5: Presentation & Inference\] \- Swift / SwiftUI

├── SwiftUI Interface (Settings, Agent Chat, Status Overlays)

├── ScreenCaptureKit (Continuous visual frame ingestion)

└── MLX Framework Engine

├── Base Model: Hybrid Mamba-Attention 8B

├── Screen2AX VLM Fallback Adapter (Local UI Reconstruction)

└── QLoRA On-Device Fine-Tuning Pipeline

       ↕ (BoltFFI / UniFFI Asynchronous Bridge with Future Cancellation)

\[Layer 4: Agent Orchestration\] \- Rust

├── Orchestrator Core (Plan-Execute-Verify Loop)

├── PARL Sub-agent Spawner (Manages concurrent task threads)

└── SQLite State Memory (Conversations, FTS5 Search, Recipe Storage)

       ↕ (Internal Memory Bus)

* Rust  
  ├── Model Context Protocol (MCP) Server (stdio transport)  
  ├── Recipe Manager (JSON workflow templates execution)  
  └── RAG Engine (Vector Embeddings indexing local files)  
      ↕ (System API Bindings)

\[Layer 2: Perception & Automation\] \- Rust & Swift

├── accessibility-sys (Rust) / AXorcist (Swift)

│ └── Ingests AXUIElement tree \-\> translates to semantic JSON

├── Process::Command (Rust)

│ └── osascript, JXA, Apple Shortcuts CLI invocation

└── CGEvent FFI (Rust)

└── Raw keystroke/mouse position simulation

       ↕

├── Target Applications (Safari, Finder, Xcode, etc.)

├── macOS Window Server

└── Native File System

**Component Specifications & Tradeoffs:**

* **Swift UI & MLX (Layer 5):** Swift is required for native UI and MLX metal bindings. Inference is heavily memory-bandwidth-bound; keeping MLX operations strictly within the Swift layer allows the system to leverage Apple Silicon's unified memory architecture without incurring the severe latency penalties associated with marshaling large tensor data across FFI boundaries.26  
* **Rust Orchestrator (Layer 4):** Ensures thread-safe execution of complex multi-agent PARL workflows.9 Rust handles the SQLite connection securely and manages the overarching state machine, ensuring minimal footprint and high concurrency.28  
* **Inter-Component Protocol:** UniFFI or BoltFFI acts as the bridge. Rust defines the interfaces (e.g., Agent.execute(prompt)). Swift implements the MLX execution and passes an asynchronous callback to Rust. The MCP server runs embedded within the main application process to achieve tighter integration and lower latency than a standalone HTTP server architecture.

## **4.2 The Virtuous Training Cycle**

To build a defensible moat, the system utilizes a continuous self-improvement loop inspired by Andrej Karpathy's "AutoResearch" repository.43

1. **Ingestion:** The user's daily interactions, successful task completions, and manual UI corrections are logged locally into the SQLite database.  
2. **Dataset Curation:** Overnight, a Rust background process extracts these logs, filtering and formatting them into Supervised Fine-Tuning (SFT) trajectory pairs.  
3. **On-Device Training:** The Swift MLX engine initializes, utilizing MoLoRA (Mixture of LoRAs) routing to fine-tune a specific user-workflow adapter directly on the M-series GPU.38  
4. **Evaluation:** The newly trained adapter is tested against a local validation set of past actions using the val\_bpb (validation bits per byte) ratchet loop.43  
5. **Deployment:** If the adapter improves validation metrics without exhibiting catastrophic forgetting, it is hot-swapped into the active inference path.

**Safeguards Against Overfitting & Reward Hacking:** Self-rewarding loops are highly susceptible to "reward hacking," where the model learns to exploit the evaluation mechanism without genuinely improving task performance.44 To mitigate this, Epistemos Omega must implement the Cluster Separation Index (CSI) derived from the InfoRM framework. CSI quantifies deviations in the latent space to detect when a model is beginning to over-optimize on spurious features.45 Additionally, rule-based trajectory verification filters are applied during data ingestion to ensure only functionally verified outcomes (e.g., a file was actually created, an email was actually sent) enter the training pool.46

## **4.3 Competitive Moat Analysis**

The architecture of Epistemos Omega establishes highly defensible advantages that incumbent competitors cannot easily replicate:

* **Versus Apple Intelligence:** Apple Intelligence limits automation to App Intents, which rely strictly on third-party developers exposing specific endpoints within their applications.27 Epistemos Omega utilizes the Accessibility Tree and the Screen2AX pixel fallback, granting it deep automation control over *any* legacy, web-based, or unoptimized application regardless of developer support.47  
* **Versus Microsoft Copilot & Google Agents:** The zero-cloud dependency of Epistemos Omega ensures strict data privacy and offline capability. This is a mandatory requirement for legal, healthcare, and enterprise intellectual property environments that cannot risk transmitting screen data to external servers.37  
* **Versus Screenpipe & Ghost OS:** Epistemos Omega transcends Screenpipe's passive memory architecture by adding autonomous execution capabilities.29 It surpasses Ghost OS by integrating custom, self-improving MLX local models rather than relying on external API keys and static cloud models.31

## ---

**Section 5: Implementation Roadmap**

| Phase | Duration | Focus Area | Deliverables | Risk Mitigations |
| :---- | :---- | :---- | :---- | :---- |
| **Phase 1** | Weeks 1-4 | Infrastructure & FFI | Rust core initialized. uniffi / BoltFFI bridging configured. accessibility-sys successfully mapping the macOS AX tree. Internal MCP server running. | **Risk:** FFI memory leaks. **Mitigation:** Implement ForeignFutureDroppedCallback for strict async task cancellation.33 |
| **Phase 2** | Weeks 5-8 | Synthetic Data & Distillation | System operated via Claude API to harvest 10,000+ real-world execution traces. Distillation of the 3B/8B Hybrid Mamba-Attention model using the MOHAWK pipeline.10 | **Risk:** Cloud API rate limits. **Mitigation:** Implement aggressive local SQLite caching and exponential backoff during synthetic data generation. |
| **Phase 3** | Weeks 9-12 | VLM Fallback & Swarm | Integration of the Screen2AX VLM for apps lacking AX support.6 Implementation of the PARL sub-agent threading in the Rust orchestrator.9 | **Risk:** Serial collapse of sub-agents. **Mitigation:** Utilize staged reward shaping to heavily penalize single-threaded execution paths during tuning.9 |
| **Ongoing** | Continuous | AutoResearch Loop | Overnight MLX LoRA training enabled. Trajectory ingestion active. val\_bpb ratchet loop running continuously.43 | **Risk:** Reward hacking. **Mitigation:** Apply InfoRM's Cluster Separation Index to detect and discard over-optimized latent representations.45 |

## ---

**Section 6: Risk Register**

| Risk | Probability | Impact | Mitigation Strategy |
| :---- | :---- | :---- | :---- |
| **1\. Pure Mamba-2 Formatting Drift** | High | Critical | Adopt a Hybrid Mamba-Attention architecture to utilize attention layers as exact-match global anchors for strict JSON schemas.1 |
| **2\. Incomplete macOS Accessibility Data** | High | Critical | Implement the Screen2AX VLM fallback to synthetically reconstruct UI hierarchies from ScreenCaptureKit pixels.6 |
| **3\. Rust/Swift Async Memory Leaks** | Medium | High | Utilize UniFFI's ForeignFutureDroppedCallback or BoltFFI's AutoCloseable structures to explicitly handle cross-boundary task cancellation.5 |
| **4\. FFI Latency Bottlenecks** | Medium | Medium | Keep memory-heavy MLX tensor operations isolated within Swift. Utilize BoltFFI for microsecond primitive passing to the Rust orchestrator.5 |
| **5\. Catastrophic Forgetting during Tuning** | Medium | High | Maintain a strict validation set of benchmark tasks (SWE-Bench style) that the AutoResearch loop must pass before deploying new adapters.17 |
| **6\. Reward Hacking in Agent Loop** | Medium | High | Implement rule-based verification filters during trajectory capture and utilize InfoRM CSI analysis to ensure functional alignment.45 |
| **7\. "Serial Collapse" of Workflows** | High | Medium | Train the orchestration model using PARL methodologies, specifically rewarding concurrent sub-task generation and penalizing critical path delays.9 |
| **8\. Apple App Store Sandbox Constraints** | High | Critical | Design for direct developer distribution initially. Sandboxing severely restricts the AppleScript, osascript, and file system access required for deep automation.48 |
| **9\. Model Hallucinating Invalid Tools** | High | Medium | Heavily weight the SFT dataset with the application's exact tool schemas; implement hard application-level type checking in the Rust MCP server. |
| **10\. Underflows during Quantization** | Low | Medium | Retain the Mamba Output Projection layer in FP8 or BF16 rather than aggressively quantizing to NVFP4, preventing numerical instability.1 |

## ---

**Bibliography**

1. 49 NVIDIA. (2026). *Introducing Nemotron 3 Super: An Open Hybrid Mamba-Transformer MoE for Agentic Reasoning*. [https://developer.nvidia.com/blog/introducing-nemotron-3-super-an-open-hybrid-mamba-transformer-moe-for-agentic-reasoning/](https://developer.nvidia.com/blog/introducing-nemotron-3-super-an-open-hybrid-mamba-transformer-moe-for-agentic-reasoning/)  
2. 16 NVIDIA. (2026). *NVIDIA-Nemotron-3-Super-120B-A12B-FP8*. Hugging Face. [https://huggingface.co/nvidia/NVIDIA-Nemotron-3-Super-120B-A12B-FP8](https://huggingface.co/nvidia/NVIDIA-Nemotron-3-Super-120B-A12B-FP8)  
3. 31 Ghostwright. (2025). *Ghost OS \- Full computer-use for AI agents*. GitHub. [https://github.com/ghostwright/ghost-os](https://github.com/ghostwright/ghost-os)  
4. 29 Screenpipe. (2025). *Screenpipe \- 100% local AI screen & audio capture*. GitHub. [https://github.com/screenpipe/screenpipe](https://github.com/screenpipe/screenpipe)  
5. 6 Muryn, V., et al. (2025). *Screen2AX: Vision-Based Approach for Automatic macOS Accessibility Generation*. arXiv:2507.16704v1. [https://arxiv.org/html/2507.16704v1](https://arxiv.org/html/2507.16704v1)  
6. 33 Mozilla. (2025). *UniFFI Async FFI Internals*. [https://mozilla.github.io/uniffi-rs/latest/internals/async-ffi.html](https://mozilla.github.io/uniffi-rs/latest/internals/async-ffi.html)  
7. 7 OpenAI. (2024). *Fine-tuning for function calling*. OpenAI Cookbook. [https://developers.openai.com/cookbook/examples/fine\_tuning\_for\_function\_calling/](https://developers.openai.com/cookbook/examples/fine_tuning_for_function_calling/)  
8. 26 Apple Machine Learning Research. (2025). *Exploring LLMs with MLX on M5*. [https://machinelearning.apple.com/research/exploring-llms-mlx-m5](https://machinelearning.apple.com/research/exploring-llms-mlx-m5)  
9. 27 Simform Engineering. (2025). *App Intents & Apple Intelligence: Unlocking the Basics*. [https://medium.com/simform-engineering/app-intents-apple-intelligence-unlocking-the-basics-2208bf896e03](https://medium.com/simform-engineering/app-intents-apple-intelligence-unlocking-the-basics-2208bf896e03)  
10. 5 BoltFFI. (2025). *BoltFFI: A high-performance Rust bindings generator*. Reddit. [https://www.reddit.com/r/rust/comments/1r768bm/boltffi\_a\_highperformance\_rust\_bindings\_generator/](https://www.reddit.com/r/rust/comments/1r768bm/boltffi_a_highperformance_rust_bindings_generator/)  
11. 43 Karpathy, A. (2025). *AutoResearch \- Recursive AI Self-Improvement*. GitHub / DataCamp Guide. [https://www.datacamp.com/tutorial/guide-to-autoresearch](https://www.datacamp.com/tutorial/guide-to-autoresearch)  
12. 45 Miao, Y., et al. (2024). *InfoRM: Information-Theoretic Reward Modeling for RLHF*. NeurIPS 2024\. [https://proceedings.neurips.cc/paper\_files/paper/2024/file/f25d75fc760aec0a6174f9f5d9da59b8-Paper-Conference.pdf](https://proceedings.neurips.cc/paper_files/paper/2024/file/f25d75fc760aec0a6174f9f5d9da59b8-Paper-Conference.pdf)  
13. 11 Mistral AI. (2024). *Codestral Mamba*. [https://mistral.ai/news/codestral-mamba](https://mistral.ai/news/codestral-mamba)  
14. 2 Wang, J., et al. (2024). *The Mamba in the Llama: Distilling and Accelerating Hybrid Models*. NeurIPS 2024\. [https://proceedings.neurips.cc/paper\_files/paper/2024/hash/723933067ad315269b620bc0d2c05cba-Abstract-Conference.html](https://proceedings.neurips.cc/paper_files/paper/2024/hash/723933067ad315269b620bc0d2c05cba-Abstract-Conference.html)  
15. 8 Zhang, Y., et al. (2025). *ODIA: Oriented Distillation for Inline Acceleration of LLM-based Function Calling*. arXiv:2507.08877. [https://arxiv.org/pdf/2507.08877](https://arxiv.org/pdf/2507.08877)  
16. 41 H Company. (2024). *Charting a new route: the tech behind Runner H's state-of-the-art results*. [https://hcompany.ai/charting-a-new-route-the-tech-behind-runner-hs-state-of-the-art-results](https://hcompany.ai/charting-a-new-route-the-tech-behind-runner-hs-state-of-the-art-results)  
17. 6 Muryn, V., et al. (2025). *Screen2AX-Tree Dataset*. Hugging Face. [https://arxiv.org/html/2507.16704v1](https://arxiv.org/html/2507.16704v1)  
18. 48 Unclutr. (2025). *Building a Swift-native MCP server for a macOS app*. Reddit. [https://www.reddit.com/r/swift/comments/1reb68v/a\_swiftnative\_mcp\_server\_lessons\_on\_stdio/](https://www.reddit.com/r/swift/comments/1reb68v/a_swiftnative_mcp_server_lessons_on_stdio/)  
19. 9 Moonshot AI. (2026). *Kimi K2.5: Parallel-Agent Reinforcement Learning Guide*. DataCamp. [https://www.datacamp.com/tutorial/kimi-k2-agent-swarm-guide](https://www.datacamp.com/tutorial/kimi-k2-agent-swarm-guide)  
20. 10 Apriel Research. (2025). *Apriel-H1: Distilling Hybrid SSM-Transformer Architectures*. arXiv:2511.02651v1. [https://arxiv.org/html/2511.02651v1](https://arxiv.org/html/2511.02651v1)  
21. 31 Ghost OS GitHub Repository Analysis. (2025). [https://github.com/ghostwright/ghost-os](https://github.com/ghostwright/ghost-os)  
22. 29 Screenpipe Architecture Documentation. (2025). [https://github.com/screenpipe/screenpipe](https://github.com/screenpipe/screenpipe)  
23. 1 NVIDIA. (2026). *Nemotron 3 Super Technical Report: Failure Modes of Pure Mamba-2*. [https://research.nvidia.com/labs/nemotron/files/NVIDIA-Nemotron-3-Super-Technical-Report.pdf](https://research.nvidia.com/labs/nemotron/files/NVIDIA-Nemotron-3-Super-Technical-Report.pdf)  
24. 34 H Company. (2025). *Surfer-H Meets Holo1: Cost-Efficient Web Agent Powered by Open Weights*. [https://arxiv.org/abs/2506.02865](https://arxiv.org/abs/2506.02865)

#### **Works cited**

1. Nemotron 3 Super: Open, Efficient Mixture-of-Experts Hybrid Mamba-Transformer Model for Agentic Reasoning \- Research at NVIDIA, accessed March 23, 2026, [https://research.nvidia.com/labs/nemotron/files/NVIDIA-Nemotron-3-Super-Technical-Report.pdf](https://research.nvidia.com/labs/nemotron/files/NVIDIA-Nemotron-3-Super-Technical-Report.pdf)  
2. The Mamba in the Llama: Distilling and Accelerating Hybrid Models \- NeurIPS, accessed March 23, 2026, [https://proceedings.neurips.cc/paper\_files/paper/2024/hash/723933067ad315269b620bc0d2c05cba-Abstract-Conference.html](https://proceedings.neurips.cc/paper_files/paper/2024/hash/723933067ad315269b620bc0d2c05cba-Abstract-Conference.html)  
3. How to build your first AI agent with MCP in Rust \- Composio, accessed March 23, 2026, [https://composio.dev/content/how-to-build-your-first-ai-agent-with-mcp-in-rust](https://composio.dev/content/how-to-build-your-first-ai-agent-with-mcp-in-rust)  
4. Async/Future support \- The UniFFI user guide, accessed March 23, 2026, [https://mozilla.github.io/uniffi-rs/0.28/futures.html](https://mozilla.github.io/uniffi-rs/0.28/futures.html)  
5. BoltFFI: a high-performance Rust bindings generator (up to 1000× vs UniFFI microbenchmarks) \- Reddit, accessed March 23, 2026, [https://www.reddit.com/r/rust/comments/1r768bm/boltffi\_a\_highperformance\_rust\_bindings\_generator/](https://www.reddit.com/r/rust/comments/1r768bm/boltffi_a_highperformance_rust_bindings_generator/)  
6. Screen2AX: Vision-Based Approach for Automatic macOS Accessibility Generation \- arXiv, accessed March 23, 2026, [https://arxiv.org/html/2507.16704v1](https://arxiv.org/html/2507.16704v1)  
7. Fine tuning for function calling \- OpenAI Developers, accessed March 23, 2026, [https://developers.openai.com/cookbook/examples/fine\_tuning\_for\_function\_calling/](https://developers.openai.com/cookbook/examples/fine_tuning_for_function_calling/)  
8. ODIA: Oriented Distillation for Inline Acceleration of LLM-based Function Calling \- arXiv, accessed March 23, 2026, [https://arxiv.org/pdf/2507.08877](https://arxiv.org/pdf/2507.08877)  
9. Kimi K2.5 and Agent Swarm: A Guide With Four Practical Examples | DataCamp, accessed March 23, 2026, [https://www.datacamp.com/tutorial/kimi-k2-agent-swarm-guide](https://www.datacamp.com/tutorial/kimi-k2-agent-swarm-guide)  
10. Apriel–H1: Towards Efficient Enterprise Reasoning Models \- arXiv, accessed March 23, 2026, [https://arxiv.org/html/2511.02651v1](https://arxiv.org/html/2511.02651v1)  
11. Codestral Mamba \- Mistral AI, accessed March 23, 2026, [https://mistral.ai/news/codestral-mamba](https://mistral.ai/news/codestral-mamba)  
12. Open source Mamba 3 arrives to surpass Transformer architecture with nearly 4% improved language modeling, reduced latency | VentureBeat, accessed March 23, 2026, [https://venturebeat.com/technology/open-source-mamba-3-arrives-to-surpass-transformer-architecture-with-nearly](https://venturebeat.com/technology/open-source-mamba-3-arrives-to-surpass-transformer-architecture-with-nearly)  
13. An Empirical Study of Mamba-based Language Models : r/LocalLLaMA \- Reddit, accessed March 23, 2026, [https://www.reddit.com/r/LocalLLaMA/comments/1devfmr/an\_empirical\_study\_of\_mambabased\_language\_models/](https://www.reddit.com/r/LocalLLaMA/comments/1devfmr/an_empirical_study_of_mambabased_language_models/)  
14. Inside NVIDIA Nemotron 3: Techniques, Tools, and Data That Make It Efficient and Accurate, accessed March 23, 2026, [https://developer.nvidia.com/blog/inside-nvidia-nemotron-3-techniques-tools-and-data-that-make-it-efficient-and-accurate/](https://developer.nvidia.com/blog/inside-nvidia-nemotron-3-techniques-tools-and-data-that-make-it-efficient-and-accurate/)  
15. NVIDIA Just Dropped the Most Efficient Reasoning Model of 2026, accessed March 23, 2026, [https://medium.com/data-science-collective/nvidia-just-dropped-the-most-efficient-reasoning-model-of-2026-cee624c5fb26](https://medium.com/data-science-collective/nvidia-just-dropped-the-most-efficient-reasoning-model-of-2026-cee624c5fb26)  
16. nvidia/NVIDIA-Nemotron-3-Super-120B-A12B-FP8 \- Hugging Face, accessed March 23, 2026, [https://huggingface.co/nvidia/NVIDIA-Nemotron-3-Super-120B-A12B-FP8](https://huggingface.co/nvidia/NVIDIA-Nemotron-3-Super-120B-A12B-FP8)  
17. Nemotron 3 Super with Agentic Coding Tools \- NVIDIA Documentation, accessed March 23, 2026, [https://docs.nvidia.com/nemotron/nightly/usage-cookbook/Nemotron-3-Super/OpenScaffoldingResources/README.html](https://docs.nvidia.com/nemotron/nightly/usage-cookbook/Nemotron-3-Super/OpenScaffoldingResources/README.html)  
18. The Mamba in the Llama: Distilling and Accelerating Hybrid Models \- NIPS, accessed March 23, 2026, [https://proceedings.neurips.cc/paper\_files/paper/2024/file/723933067ad315269b620bc0d2c05cba-Paper-Conference.pdf](https://proceedings.neurips.cc/paper_files/paper/2024/file/723933067ad315269b620bc0d2c05cba-Paper-Conference.pdf)  
19. Mistral structured output should use \`json\_schema\` with \`strict: true\` instead of \`json\_object\` · Issue \#4762 \- GitHub, accessed March 23, 2026, [https://github.com/pydantic/pydantic-ai/issues/4762](https://github.com/pydantic/pydantic-ai/issues/4762)  
20. Kimi K2.5: Visual Agentic Intelligence \- arXiv.org, accessed March 23, 2026, [https://arxiv.org/html/2602.02276v1](https://arxiv.org/html/2602.02276v1)  
21. (PDF) Kimi K2.5: Visual Agentic Intelligence \- ResearchGate, accessed March 23, 2026, [https://www.researchgate.net/publication/400395205\_Kimi\_K25\_Visual\_Agentic\_Intelligence](https://www.researchgate.net/publication/400395205_Kimi_K25_Visual_Agentic_Intelligence)  
22. Characterizing and Mitigating Reasoning Drift in Large Language Models \- OpenReview, accessed March 23, 2026, [https://openreview.net/forum?id=OphrMOQCCY](https://openreview.net/forum?id=OphrMOQCCY)  
23. Use scripts with Automator on Mac \- Apple Support (TM), accessed March 23, 2026, [https://support.apple.com/en-tm/guide/automator/aut4bb6b2b4f/mac](https://support.apple.com/en-tm/guide/automator/aut4bb6b2b4f/mac)  
24. An MCP server to run AppleScript and JXA (JavaScript for Automation) to macOS. \- GitHub, accessed March 23, 2026, [https://github.com/steipete/macos-automator-mcp](https://github.com/steipete/macos-automator-mcp)  
25. Reinforcement fine-tuning | OpenAI API, accessed March 23, 2026, [https://developers.openai.com/api/docs/guides/reinforcement-fine-tuning](https://developers.openai.com/api/docs/guides/reinforcement-fine-tuning)  
26. Exploring LLMs with MLX and the Neural Accelerators in the M5 GPU, accessed March 23, 2026, [https://machinelearning.apple.com/research/exploring-llms-mlx-m5](https://machinelearning.apple.com/research/exploring-llms-mlx-m5)  
27. App Intents & Apple Intelligence: Enhance App Experience | by Rizwana Desai \- Medium, accessed March 23, 2026, [https://medium.com/simform-engineering/app-intents-apple-intelligence-unlocking-the-basics-2208bf896e03](https://medium.com/simform-engineering/app-intents-apple-intelligence-unlocking-the-basics-2208bf896e03)  
28. How to Build an MCP Server in Rust \- OneUptime, accessed March 23, 2026, [https://oneuptime.com/blog/post/2026-01-07-rust-mcp-server/view](https://oneuptime.com/blog/post/2026-01-07-rust-mcp-server/view)  
29. screenpipe turns your computer into a personal AI that knows everything you've done. record. search. automate. all local, all private, all yours. \- GitHub, accessed March 23, 2026, [https://github.com/screenpipe/screenpipe](https://github.com/screenpipe/screenpipe)  
30. architecture \- screenpipe docs, accessed March 23, 2026, [https://docs.screenpi.pe/architecture](https://docs.screenpi.pe/architecture)  
31. GitHub \- ghostwright/ghost-os: Full computer-use for AI agents. Self-learning workflows. Native macOS. No screenshots required., accessed March 23, 2026, [https://github.com/ghostwright/ghost-os](https://github.com/ghostwright/ghost-os)  
32. AXorcist • Swift wrapper for macOS Accessibility—chainable, fuzzy-matched queries that read, click, and inspect any UI. The power of Swift compels your UI to obey\! \- GitHub, accessed March 23, 2026, [https://github.com/steipete/AXorcist](https://github.com/steipete/AXorcist)  
33. UniFFI Async FFI details, accessed March 23, 2026, [https://mozilla.github.io/uniffi-rs/latest/internals/async-ffi.html](https://mozilla.github.io/uniffi-rs/latest/internals/async-ffi.html)  
34. Introduction \- H Tech Hub, accessed March 23, 2026, [https://hub.hcompany.ai/models/Holo1/aboutholo1](https://hub.hcompany.ai/models/Holo1/aboutholo1)  
35. Runner H & Surfer H: A Masterclass in Modern Browser-Use Agents \- Medium, accessed March 23, 2026, [https://medium.com/@kram254/runner-h-surfer-h-a-masterclass-in-modern-browser-use-agents-fb68cb666b29](https://medium.com/@kram254/runner-h-surfer-h-a-masterclass-in-modern-browser-use-agents-fb68cb666b29)  
36. New NVIDIA Nemotron 3 Super Delivers 5x Higher Throughput for Agentic AI, accessed March 23, 2026, [https://blogs.nvidia.com/blog/nemotron-3-super-agentic-ai/](https://blogs.nvidia.com/blog/nemotron-3-super-agentic-ai/)  
37. Acceptable use requirements for the Foundation Models framework \- Apple Intelligence, accessed March 23, 2026, [https://developer.apple.com/apple-intelligence/acceptable-use-requirements-for-the-foundation-models-framework/](https://developer.apple.com/apple-intelligence/acceptable-use-requirements-for-the-foundation-models-framework/)  
38. Everything you wanted to know about Apple's MLX : r/LocalLLaMA \- Reddit, accessed March 23, 2026, [https://www.reddit.com/r/LocalLLaMA/comments/1l7yrni/everything\_you\_wanted\_to\_know\_about\_apples\_mlx/](https://www.reddit.com/r/LocalLLaMA/comments/1l7yrni/everything_you_wanted_to_know_about_apples_mlx/)  
39. Continual learning in the federated-learning context \- Amazon Science, accessed March 23, 2026, [https://www.amazon.science/blog/continual-learning-in-the-federated-learning-context](https://www.amazon.science/blog/continual-learning-in-the-federated-learning-context)  
40. Build RAG Chatbot with LangChain, Faiss, Mistral AI Codestral Mamba, and OpenAI text-embedding-ada-002 \- Zilliz, accessed March 23, 2026, [https://zilliz.com/tutorials/rag/langchain-and-faiss-and-mistral-ai-codestral-mamba-and-openai-text-embedding-ada-002](https://zilliz.com/tutorials/rag/langchain-and-faiss-and-mistral-ai-codestral-mamba-and-openai-text-embedding-ada-002)  
41. Charting a New Route: The Tech Behind Runner H's State-of-the-Art Results \- hcompany.ai, accessed March 23, 2026, [https://hcompany.ai/charting-a-new-route-the-tech-behind-runner-hs-state-of-the-art-results](https://hcompany.ai/charting-a-new-route-the-tech-behind-runner-hs-state-of-the-art-results)  
42. Your Company Needs Small Language Models \- Medium, accessed March 23, 2026, [https://medium.com/data-science/your-company-needs-small-language-models-d0a223e0b6d9](https://medium.com/data-science/your-company-needs-small-language-models-d0a223e0b6d9)  
43. A Guide to Andrej Karpathy's AutoResearch: Automating ML with AI Agents | DataCamp, accessed March 23, 2026, [https://www.datacamp.com/tutorial/guide-to-autoresearch](https://www.datacamp.com/tutorial/guide-to-autoresearch)  
44. Natural emergent misalignment from reward hacking in production RL \- arXiv, accessed March 23, 2026, [https://arxiv.org/html/2511.18397v1](https://arxiv.org/html/2511.18397v1)  
45. Mitigating Reward Hacking in RLHF via Information-Theoretic Reward Modeling \- NIPS, accessed March 23, 2026, [https://proceedings.neurips.cc/paper\_files/paper/2024/file/f25d75fc760aec0a6174f9f5d9da59b8-Paper-Conference.pdf](https://proceedings.neurips.cc/paper_files/paper/2024/file/f25d75fc760aec0a6174f9f5d9da59b8-Paper-Conference.pdf)  
46. NVIDIA Nemotron Nano 2: An Accurate and Efficient Hybrid Mamba-Transformer Reasoning Model, accessed March 23, 2026, [https://research.nvidia.com/labs/adlr/files/NVIDIA-Nemotron-Nano-2-Technical-Report.pdf](https://research.nvidia.com/labs/adlr/files/NVIDIA-Nemotron-Nano-2-Technical-Report.pdf)  
47. Aligning AI agent intent: A framework for secure and governable AI, accessed March 23, 2026, [https://techcommunity.microsoft.com/blog/microsoft-security-blog/aligning-ai-agent-intent-a-framework-for-secure-and-governable-ai/4503551](https://techcommunity.microsoft.com/blog/microsoft-security-blog/aligning-ai-agent-intent-a-framework-for-secure-and-governable-ai/4503551)  
48. A Swift-native MCP server: lessons on stdio, sandboxing, and packaging \- Reddit, accessed March 23, 2026, [https://www.reddit.com/r/swift/comments/1reb68v/a\_swiftnative\_mcp\_server\_lessons\_on\_stdio/](https://www.reddit.com/r/swift/comments/1reb68v/a_swiftnative_mcp_server_lessons_on_stdio/)  
49. Introducing Nemotron 3 Super: An Open Hybrid Mamba-Transformer MoE for Agentic Reasoning | NVIDIA Technical Blog, accessed March 23, 2026, [https://developer.nvidia.com/blog/introducing-nemotron-3-super-an-open-hybrid-mamba-transformer-moe-for-agentic-reasoning/](https://developer.nvidia.com/blog/introducing-nemotron-3-super-an-open-hybrid-mamba-transformer-moe-for-agentic-reasoning/)