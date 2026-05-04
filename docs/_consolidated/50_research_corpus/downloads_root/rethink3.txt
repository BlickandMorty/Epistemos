Technical Analysis of Agent Architectures and Quantization Strategies for macOS-Native Knowledge Systems
The architectural evolution of the Epistemos system, specifically the transition from a Python-based subprocess model to a high-performance, macOS-native Rust agent runtime, marks a critical shift in the design of cognitive exoskeletons. This report provides an exhaustive technical evaluation of open-source agent frameworks, model architectures, and quantization strategies to support a pure Swift and Rust implementation leveraging Apple Silicon’s Unified Memory Architecture and Metal compute shaders.
Agent Framework Verdict and Architectural Selection
The landscape of open-source agent frameworks has diverged into two primary philosophies: the orchestrator-centric model and the model-centric "mind" model. For the requirements of Epistemos—specifically the need for a low-latency, zero-copy IPC, and a compact binary footprint—the selection of a foundational framework must prioritize Rust-native performance and protocol standardization.


Project
	Verdict
	Core Rationale
	Block Goose
	Clone
	Highly modular Rust architecture with first-class MCP support and a clean Provider abstraction.1
	OpenHarness
	Study
	Offers strong terminal-based Git integration and permission patterns but relies on a TypeScript-heavy UI stack.3
	Hermes Agent Self-Evolution
	Take From
	Provides the most advanced logic for autonomous skill creation and reflective learning loops.4
	SciAgent-Skills
	Take From
	A massive repository of specialized scientific domain knowledge and curated tool documentation.6
	Evaluation of Block Goose
Goose represents the most technologically aligned framework for the Epistemos migration. Built primarily in Rust, it utilizes a workspace of crates that separate the core agent logic from the transport and interface layers.1 The core goose crate implements the agentic loop, while goose-mcp provides a robust implementation of the Model Context Protocol.7 The decision to clone the Goose architecture is driven by its Apache-2.0 license and its alignment with the goal of a 5-15MB agent binary.2 While the current distribution sizes for macOS are larger, around 60MB for the full CLI, aggressive optimization of the core crate alone can meet the desired targets.11
Evaluation of OpenHarness
OpenHarness is a terminal-based agent harness that excels in local-first workflows via Ollama integration.3 It serves as a provider-agnostic harness supporting eighteen built-in tools with permission gates.3 While the project is mature in its CLI implementation, it compares less favorably to Goose for deep integration into a Swift/Rust native app due to its heavier reliance on React and Ink for the user interface.3 It should be studied for its /undo command logic and Git-aware file editing patterns, which can improve the Epistemos diff engine.3
Evaluation of Hermes Agent Self-Evolution
The Hermes Agent self-evolution project by Nous Research focuses on GEPA (Genetic-Pareto Prompt Evolution) and DSPy-based optimization.5 Unlike traditional agents that follow static scripts, Hermes treats the agent loop as a "do, learn, improve" cycle.12 This project is essential for the Epistemos "Living Vault" because it introduces a mechanism for the agent to evaluate its own performance and curate its own memory by writing reusable procedural "skills" directly to disk.13 While the current implementation is Python-based, the underlying logic of creating skill documents after solving complex workflows is highly portable to a Rust-native runtime.4
Evaluation of SciAgent-Skills
SciAgent-Skills provides 196 ready-to-use scientific skills covering genomics, drug discovery, and biostatistics.6 These skills are formatted as self-contained markdown files that the agent can read and execute, providing practical code examples and troubleshooting guides.6 Integrating these skills into Epistemos will significantly enhance the one-click research feature (⌘R) by providing the agent with pre-defined expertise in specialized scientific Python packages.6
Block Goose Deep Dive and Implementation Strategy
The Block Goose framework's architecture is the primary template for the Epistemos Phase I migration. The following analysis dissects the specific Rust modules and traits necessary for the pure Rust agent runtime.
The Provider Trait and Model Abstraction
The Provider trait, defined in crates/goose/src/providers/base.rs, is the foundational abstraction for model interaction.1 It uses the async_trait macro to handle asynchronous streaming and completions across different backends.1


Method
	Functionality
	Epistemos Adaptation
	stream()
	Orchestrates real-time token streaming and tool call injection.1
	Bridge to MLX-Swift for local inference or OpenAI/Anthropic for cloud.16
	complete()
	Handles non-streaming requests for batch processing.1
	Primary interface for background vault summarization.17
	get_model_config()
	Retrieves window limits, token costs, and capability flags.1
	Integrated with Epistemos 3-tier power management.16
	generate_session_name()
	Uses a cheap model to generate titles from context.1
	Offloaded to the Router model for local efficiency.16
	By cloning this trait, Epistemos can create a unified MLXProvider in the agent_core crate. This implementation will leverage Metal-optimized local inference while maintaining compatibility with the same tool-calling logic used for cloud providers. The ability to define declarative providers via JSON further allows for rapid integration of new local models without recompiling the core agent logic.1
The Agent Loop and Reply Internal Flow
The core interaction logic in crates/goose/src/agents/agent.rs revolves around the reply_internal() method.1 This loop handles the transition between user input, model generation, tool invocation, and result synthesis.1 Goose implements a sophisticated context compaction strategy, governed by the SessionManager, which monitors the context window usage.1
When the GOOSE_AUTO_COMPACT_THRESHOLD is reached, typically at 80% of the context window, the agent automatically summarizes the earlier parts of the conversation.17 This logic is superior to simple sliding windows as it preserves essential intent and results while discarding redundant tokens. Epistemos should replace its current agent_loop.rs with a Rust implementation of this flow, specifically integrating the "Living Vault" diff engine into the tool-result synthesis phase to maintain the git-as-journal integrity.
Rust MCP Implementation and Builtin Extensions
The goose-mcp crate provides a pure Rust implementation of the Model Context Protocol, which is essential for eliminating the Python bridge.1 Goose differentiates between builtin extensions and external MCP servers.7 Builtin extensions are compiled directly into the binary and use the rmcp::ServerHandler trait over a DuplexStream, ensuring zero IPC overhead and near-instantaneous execution.1
For the 17 core coding tools required by Epistemos—such as file read/write, bash execution, and semantic search—the builtin extension pattern is the only way to achieve the <10ms cold start target.21 These extensions will handle OS-specific implementations for macOS natively, bypassing the need for an external bridge process.22
Security and Tool Inspection
The ToolInspectionManager in Goose provides a template for managing security and egress.21 It includes inspectors for identifying repetition, detecting potential adversary prompts, and enforcing security boundaries on file system access via .gooseignore files.21 This is a significant improvement over the forked Hermes agent, which lacks a standardized security harness for tool execution.
Binary Size and Runtime Optimization
A critical requirement for Epistemos is a compact agent binary (5-15MB).10 While the standard Rust release profile can produce larger binaries due to debug symbols and the standard library, several optimizations can be applied:


Optimization
	Method
	Impact
	Strip Debug Symbols
	strip = true in Cargo.toml
	Removes symbol names and traceback data, reducing size significantly.10
	Optimization Level
	opt-level = "z"
	Prioritizes minimal code size over raw execution speed.10
	Link-Time Optimization
	lto = true
	Enables whole-program analysis to remove dead code across crates.26
	Panic Behavior
	panic = "abort"
	Eliminates unwinding code, reducing the binary footprint of error handling.10
	Codegen Units
	codegen-units = 1
	Provides the optimizer with a broader view for inlining and dead code elimination.26
	By applying these flags and utilizing cargo-bloat to identify and remove heavy dependencies, the agent_core crate can be optimized for the 15MB target, ensuring it does not bloat the macOS application bundle.26
Local Model Evaluation for Apple Silicon
The efficacy of the Epistemos agent system depends on the selection of local models that can fit within the unified memory constraints of an M2 Pro (18GB RAM) while providing reliable tool-calling and reasoning capabilities.
Gemma 4 Performance and Architecture
The Gemma 4 model family, released under the Apache 2.0 license, is purpose-built for advanced reasoning and agentic workflows.27 It introduces an unprecedented level of intelligence-per-parameter, with specific optimizations for mobile and edge deployment.28


Model Size
	Architecture
	Context
	Benchmarks (MMLU Pro)
	RAM (4-bit)
	E2B
	Dense
	128K
	60.0%
	~3GB 30
	E4B
	Dense
	128K
	69.4%
	~5GB 30
	26B-A4B
	MoE
	256K
	82.6%
	~16GB 31
	31B
	Dense
	256K
	85.2%
	~18GB 31
	The 26B-A4B variant is particularly noteworthy. As a Mixture-of-Experts (MoE) model, it contains 25.2B total parameters but activates only 3.8B per token.29 This allows it to achieve approximately 97% of the performance of the dense 31B model while running at a fraction of the compute cost.29 On an M2 Pro with 18GB of unified memory, the 26B-A4B model in 4-bit quantization (UD-Q4_K_M at 16.9GB) can technically fit, but it leaves very little room for the operating system and the KV cache.30
Unsloth Dynamic 2.0 and Per-Tensor Quantization
Unsloth's Dynamic 2.0 quantization offers a superior alternative to standard GGUF quants.35 It employs a revamped layer selection strategy that dynamically adjusts the quantization type for every layer based on KL Divergence (KLD) benchmarks.35
The core of the Unsloth recipe for MLX involves assigning precision based on a tensor's sensitivity to degradation and its ability to be corrected via AWQ (Activation-Aware Weight Quantization).36 For example, the lm_head and Router gates are kept at higher precision (6-bit or 8-bit), while safer weights like mlp.gate_proj are compressed to 3-bit.36 This results in a model that is often 2GB smaller than a naive 4-bit quant while maintaining higher accuracy.35
Qwopus 3.5 and TurboQuant TQ3_4S
The Qwopus 3.5 27B v3 model utilizes the TQ3_4S format, which is a 3.5-bit Walsh-Hadamard-transform weight format.37 It features four per-8 scales per 32-weight block and has been validated as high-quality for reasoning tasks, derived from the Qwen 3.5 family.37 While it fits within 14GB in GGUF format, its primary limitation for Epistemos is the lack of native MLX compatibility, requiring a specialized llama.cpp-tq3 runtime.37
Model Recommendations by Use Case
For a production macOS environment on M2 Pro (18GB), the following models are recommended to satisfy the multi-tier power management and agentic loop reliability requirements.
Router Model: Gemma 4 E2B
The E2B model is the optimal "always pinned" router.27 It requires less than 3GB of RAM and achieves 133 tok/s prefill and 7.6 tok/s decode on a Raspberry Pi 5, implying significantly higher performance on M2 Pro.29 Its native support for thinking mode and function calling makes it ideal for intent classification and determining whether a task requires a more powerful reasoner model.27
* Model: Gemma 4 E2B-it 32
* Quant: 6-bit (Q6_K)
* Footprint: ~2.5GB
* Performance: 100+ tok/s
* Rationale: Low-latency intent classification with multimodal reasoning.30
Reasoner Model: Gemma 4 26B-A4B
The 26B-A4B MoE model is the superior choice for complex reasoning and long-form writing when the user requires maximum depth.29 It activates only 3.8B parameters, providing the inference speed of a small model with the reasoning depth of a large one.29
* Model: Gemma 4 26B-A4B-it 32
* Quant: 4-bit (UD-Q4_K_M) 33
* Footprint: ~16.9GB (Cold-loaded) 33
* Performance: 30+ tok/s 30
* Rationale: Frontier-level performance at a fraction of the compute cost of dense 30B+ models.28
Agent Model: Qwen 3.5 9B
For the interactive agent loop that relies on precise tool-calling, the Qwen 3.5 9B model quantized via Unsloth Dynamic 2.0 is the most reliable option.39 It maintains high accuracy for structured JSON output, which is critical for preventing tool-calling failures.39
* Model: Qwen 3.5 9B 40
* Quant: 4-bit (Dynamic 2.0) 35
* Footprint: ~6GB
* Performance: 50-60 tok/s 24
* Rationale: Exceptional tool-calling reliability and native Apple Silicon optimization via the Unsloth MLX recipe.36
TurboQuant and KV Cache Compression Analysis
The memory bottleneck for local inference on Apple Silicon is often not the model weights themselves, but the Key-Value (KV) cache, especially during long-context agent sessions. TurboQuant addresses this by providing extreme compression for the KV cache.42
TurboQuant Mechanism
TurboQuant enables lossless 3-bit KV cache compression, resulting in a 6x reduction in memory usage compared to FP32.42 It utilizes a two-stage process:
1. PolarQuant: Applies random rotation to data vectors using a Walsh-Hadamard Transform (WHT). This rotation simplifies the geometry of the data, allowing a standard high-quality quantizer to capture the core concepts of the vector.42
2. QJL Algorithm: Uses a "1-bit trick" based on the Johnson-Lindenstrauss Transform to capture the remaining error. This stage acts as a mathematical error-checker that eliminates bias, ensuring accurate attention scores without retraining or fine-tuning.42
Performance and Benchmarks on Apple Silicon
On M4 and M5 hardware, TurboQuant has demonstrated significant throughput improvements, particularly at long contexts.45


KV Cache Type
	Compression
	Gen Throughput (110K tokens)
	Context Memory (8B model)
	FP16 (Baseline)
	1.0x
	38.0 tok/s
	5,182 MiB 45
	Q4_0
	3.6x
	24.0 tok/s (-36.8%)
	1,440 MiB 45
	TurboQuant TQ3
	4.4x
	11.4 tok/s (CPU-only)
	1,182 MiB 45
	TQ on MLX (Metal)
	4.6x
	0.98x of FP16 speed
	~900 MiB 46
	The 37% generation penalty observed with standard Q4_0 quantization in llama.cpp is primarily due to per-token dequantization overhead.45 TurboQuant eliminates this bottleneck by enabling direct computation on quantized values or using fused Metal kernels that maintain 98% of FP16 speed while achieving a 4.6x cache reduction.45
For the Epistemos system, which features a 256K context window for larger models, TurboQuant is the only viable path to preventing "prompt throughput collapse".38 The existing "Stateful Rotor" pipeline should be updated to implement fused Metal kernels for the Walsh-Hadamard rotation and scalar quantization, as demonstrated in recent community MLX implementations.46
Integration Roadmap: Phase I Migration
The transition to a pure Rust agent runtime is structured into five concurrent development tracks, leveraging the findings from the Goose and Hermes frameworks.
Track 1: Core Runtime Migration (from Goose)
The agent_core crate will be restructured to mirror the Goose workspace.1
1. Clone and Adapt: Clone the Provider trait and the Agent loop logic from crates/goose.1
2. MCP Integration: Use the goose-mcp crate and the rmcp library as the unified bridge for all tools.7
3. Builtin Tools: Port the existing 50+ tools into Rust-native builtin extensions. This includes the 17 core coding tools and the Metal-rendered graph search tools.21
4. UniFFI Bridge: Expose the Agent and SessionManager structs to Swift 6 via UniFFI, ensuring zero-copy IPC between the Rust backend and the Swift frontend.1
Track 2: Model and Quantization Deployment
The system will move to a multi-model tiering strategy using Unsloth Dynamic 2.0 quants.35
1. Resident Model: Deploy Gemma 4 E2B as the always-pinned router and intent classifier.30
2. Agent Model: Use Qwen 3.5 9B with per-tensor quantization as the primary tool-calling engine.36
3. TurboQuant Upgrade: Implement the Walsh-Hadamard rotation in the MLX-Swift prefill and decode kernels to support 3-bit KV cache compression (TQ3).46
Track 3: Scientific Skill Integration (from SciAgent)
Epistemos will leverage the SciAgent-Skills repository to enhance its research capabilities.6
1. Skill Loader: Implement a markdown parser in Rust that can load SKILL.md files from the SciAgent-Skills directory into the agent’s context.6
2. One-Click Research (⌘R): Map specific scientific categories (Genomics, Drug Discovery) to these skills, allowing the agent to automatically utilize specialized Python packages via isolated MCP environments.6
Track 4: Self-Evolution Port (from Hermes)
The self-improvement loop will be ported from the Python Hermes implementation to native Rust.4
1. Skill Creation: Implement the logic to abstract successful task traces into reusable markdown skills stored in the user's vault.4
2. GEPA Refinement: Port the reflective evolutionary search logic to Rust, allowing the agent to optimize its own tool descriptions and system prompts overnight based on the previous day’s execution traces.5
Track 5: Optimization and Binary Minimization
Targeting the 15MB binary and <10ms cold start latency.10
1. Aggressive Strip: Use strip = true and panic = "abort" to minimize the binary footprint.10
2. Builtin Predominance: Ensure all high-frequency tools are builtin extensions to eliminate IPC overhead.7
3. LTO Optimization: Enable fat Link-Time Optimization across the entire agent_core workspace.26


Metric
	Current (Python Subprocess)
	Target (Rust Native)
	Method
	Binary Size
	~250MB (venv + deps)
	15MB
	Rust opt-level = "z".10
	Cold Start
	~1.5s
	<10ms
	Builtin MCP extensions.21
	Context Window
	32K (FP16 limited)
	256K
	TurboQuant TQ3 compression.45
	Tool IPC
	Subprocess pipe (slow)
	Zero-copy / In-process
	Goose Builtin Extension pattern.1
	The successful execution of this roadmap will result in a world-class, macOS-native cognitive exoskeleton that combines the speed of local Rust-native logic with the reasoning depth of the latest frontier-level MoE models. By leveraging the Goose architectural framework and Unsloth's dynamic quantization, Epistemos will achieve a level of on-device intelligence and efficiency that sets a new benchmark for personal knowledge management systems.
Works cited
1. Codebase Architecture - Goose - Mintlify, accessed April 3, 2026, https://mintlify.com/block/goose/development/architecture
2. block/goose: an open source, extensible AI agent that goes beyond code suggestions - install, execute, edit, and test with any LLM - GitHub, accessed April 3, 2026, https://github.com/block/goose
3. zhijiewong/openharness: Open-source agent harness ... - GitHub, accessed April 3, 2026, https://github.com/zhijiewong/openharness
4. NousResearch/hermes-agent: The agent that grows with you - GitHub, accessed April 3, 2026, https://github.com/nousresearch/hermes-agent
5. NousResearch/hermes-agent-self-evolution: Evolutionary ... - GitHub, accessed April 3, 2026, https://github.com/NousResearch/hermes-agent-self-evolution
6. jaechang-hits/SciAgent-Skills: Life sciences computational skills for scientific AI agents - GitHub, accessed April 3, 2026, https://github.com/jaechang-hits/SciAgent-Skills
7. Deep Dive into goose's Extension System and Model Context Protocol (MCP), accessed April 3, 2026, https://dev.to/lymah/deep-dive-into-gooses-extension-system-and-model-context-protocol-mcp-3ehl
8. MCP Protocol - Goose - Mintlify, accessed April 3, 2026, https://mintlify.com/block/goose/development/mcp-protocol
9. Introduction - Goose - Mintlify, accessed April 3, 2026, https://mintlify.com/block/goose/introduction
10. johnthagen/min-sized-rust: How to minimize Rust binary size https://github.com/johnthagen/min-sized-rust · GitHub - GitHub, accessed April 3, 2026, https://github.com/johnthagen/min-sized-rust
11. Releases · block/goose - GitHub, accessed April 3, 2026, https://github.com/block/goose/releases
12. AI 101: Hermes Agent – OpenClaw's Rival? Differences and Best Use Cases - Turing Post, accessed April 3, 2026, https://www.turingpost.com/p/hermes
13. OpenClaw vs Hermes Agent: Which one should i Use? : r/AgentsOfAI - Reddit, accessed April 3, 2026, https://www.reddit.com/r/AgentsOfAI/comments/1s9h1ag/openclaw_vs_hermes_agent_which_one_should_i_use/
14. Hermes Self Evolving AI Agent Keeps Learning From Your Work : r/AISEOInsider - Reddit, accessed April 3, 2026, https://www.reddit.com/r/AISEOInsider/comments/1s7ffmr/hermes_self_evolving_ai_agent_keeps_learning_from/
15. GitHub - K-Dense-AI/claude-scientific-skills: A set of ready to use Agent Skills for research, science, engineering, analysis, finance and writing., accessed April 3, 2026, https://github.com/K-Dense-AI/claude-scientific-skills
16. Providers - Goose - Mintlify, accessed April 3, 2026, https://www.mintlify.com/block/goose/concepts/providers
17. Frequently Asked Questions - Goose - Mintlify, accessed April 3, 2026, https://www.mintlify.com/block/goose/troubleshooting/faq
18. Research → Plan → Implement Pattern | goose - GitHub Pages, accessed April 3, 2026, https://block.github.io/goose/docs/tutorials/rpi/
19. AGENTS.md - block/goose - GitHub, accessed April 3, 2026, https://github.com/block/goose/blob/main/AGENTS.md
20. Configuration Files | goose - GitHub Pages, accessed April 3, 2026, https://block.github.io/goose/docs/guides/config-files/
21. Using Extensions | goose - GitHub Pages, accessed April 3, 2026, https://block.github.io/goose/docs/getting-started/using-extensions/
22. Built-in Extensions - Goose - Mintlify, accessed April 3, 2026, https://mintlify.com/block/goose/api/extensions/builtin
23. Turning block/goose into an AI SRE Agent - DEV Community, accessed April 3, 2026, https://dev.to/nietzscheson/turning-blockgoose-into-an-ai-sre-agent-1465
24. AI Integration in Bluefin - Dosu, accessed April 3, 2026, https://app.dosu.dev/e3630b91-3a35-46b9-a8d3-b0c1b3ef6331/documents/8cd50a9b-8728-441d-a820-05d7e389484b
25. Making Rust binaries smaller by default | Kobzol's blog, accessed April 3, 2026, https://kobzol.github.io/rust/cargo/2024/01/23/making-rust-binaries-smaller-by-default.html
26. Binary Size - Rust Project Primer, accessed April 3, 2026, https://rustprojectprimer.com/building/size.html
27. Google's Gemma 4 is now available with Apache 2.0 licensing for the first time, accessed April 3, 2026, https://the-decoder.com/googles-gemma-4-is-now-available-with-apache-2-0-licensing-for-the-first-time/
28. Gemma 4: Byte for byte, the most capable open models, accessed April 3, 2026, https://blog.google/innovation-and-ai/technology/developers-tools/gemma-4/
29. Comprehensive interpretation of Google Gemma 4: 4 open-source models, Apache 2.0 license, and 6 core upgrades, accessed April 3, 2026, https://help.apiyi.com/en/google-gemma-4-open-model-apache2-multimodal-guide-en.html
30. You can now run Google's Gemma 4 model on your local device! (6GB RAM) - Reddit, accessed April 3, 2026, https://www.reddit.com/r/selfhosted/comments/1sarnf5/you_can_now_run_googles_gemma_4_model_on_your/
31. Gemma 4 released : r/LocalLLaMA - Reddit, accessed April 3, 2026, https://www.reddit.com/r/LocalLLaMA/comments/1salijj/gemma_4_released/
32. Gemma 4 - a mlx-community Collection - Hugging Face, accessed April 3, 2026, https://huggingface.co/collections/mlx-community/gemma-4
33. unsloth/gemma-4-26B-A4B-it-GGUF · Hugging Face, accessed April 3, 2026, https://huggingface.co/unsloth/gemma-4-26B-A4B-it-GGUF
34. What Is Google Gemma 4? Architecture, Benchmarks, and Why It Matters - WaveSpeed AI, accessed April 3, 2026, https://wavespeed.ai/blog/posts/what-is-google-gemma-4/
35. Unsloth Dynamic 2.0 GGUFs, accessed April 3, 2026, https://unsloth.ai/docs/basics/unsloth-dynamic-2.0-ggufs
36. Unsloth MLX: Bring Dynamic 2.0 Per-Tensor Quantization to Apple Silicon | Moonglade, accessed April 3, 2026, https://lyn.one/unsloth-quantize-recipe
37. YTan2000/Qwopus3.5-27B-v3-TQ3_4S · Hugging Face, accessed April 3, 2026, https://huggingface.co/YTan2000/Qwopus3.5-27B-v3-TQ3_4S
38. Google's Gemma 4 Just Made Cloud AI Optional. | by Borislav Bankov | Apr, 2026 | Medium, accessed April 3, 2026, https://medium.com/@borislavbankov/googles-gemma-4-just-made-cloud-ai-optional-30145cd35f62
39. Qwen3.5 - How to Run Locally | Unsloth Documentation, accessed April 3, 2026, https://unsloth.ai/docs/models/qwen3.5
40. Unsloth Dynamic 2.0 Quants - a unsloth Collection - Hugging Face, accessed April 3, 2026, https://huggingface.co/collections/unsloth/unsloth-dynamic-20-quants
41. Bring the Unsloth Dynamic 2.0 Quantize to MLX : r/LocalLLaMA - Reddit, accessed April 3, 2026, https://www.reddit.com/r/LocalLLaMA/comments/1s2h8qr/bring_the_unsloth_dynamic_20_quantize_to_mlx/
42. TurboQuant vs Traditional Quantization Eliminating Memory Overhead in LLMs - Medium, accessed April 3, 2026, https://medium.com/@tahirbalarabe2/turboquant-vs-traditional-quantization-eliminating-memory-overhead-in-llms-24524af4adb8
43. TurboQuant: Redefining AI efficiency with extreme compression - Google Research, accessed April 3, 2026, https://research.google/blog/turboquant-redefining-ai-efficiency-with-extreme-compression/
44. TurboQuant on Apple MacOS: Five Integration Paths for Local KV Cache Compression, accessed April 3, 2026, https://medium.com/@michael.hannecke/turboquant-on-apple-macos-five-integration-paths-for-local-kv-cache-compression-42e83959d414
45. TurboQuant - Extreme KV Cache Quantization · ggml-org llama.cpp · Discussion #20969, accessed April 3, 2026, https://github.com/ggml-org/llama.cpp/discussions/20969
46. TurboQuant on MLX: 4.6x KV cache compression with custom Metal kernels (Qwen 32B at 98% FP16 speed) : r/LocalLLaMA - Reddit, accessed April 3, 2026, https://www.reddit.com/r/LocalLLaMA/comments/1s5vhf6/turboquant_on_mlx_46x_kv_cache_compression_with/
47. alexcovo/qwen35-9b-mlx-turboquant-tq3 - Hugging Face, accessed April 3, 2026, https://huggingface.co/alexcovo/qwen35-9b-mlx-turboquant-tq3
48. rmcp - crates.io: Rust Package Registry, accessed April 3, 2026, https://crates.io/crates/rmcp