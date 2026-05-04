# **Deterministic Token Generation: Architectural Analysis of Constrained Decoding within the MLX Swift Ecosystem**

The rapid maturation of the MLX framework on Apple Silicon has facilitated a transition from experimental large language model inference to production-grade applications where the reliability of output structure is paramount. As developers seek to integrate local models into complex agentic workflows, the stochastic nature of token prediction must be reconciled with the deterministic requirements of data interchange formats such as JSON and specialized tool-calling protocols. The architectural challenge lies in the efficient interception and modification of the model's output distribution, a process known as constrained decoding. This report examines the native Swift infrastructure for implementing such constraints, evaluates the utility of emerging community libraries, and explores the feasibility of multi-process bridging strategies to leverage established Python-based grammar engines.

## **Architectural Foundations of the MLX Swift Logit Interception API**

The primary mechanism for steering the output of a language model in the MLX Swift ecosystem is the LogitProcessor protocol. This interface is defined within the MLXLMCommon library and serves as an optional visitor of the logits produced during each generation step.1 To understand the implementation of a GrammarConstrainedGenerator, it is first necessary to analyze the lifecycle of token generation and the specific hooks provided by the framework for intervention.

## **The LogitProcessor and LogitSampler Protocols**

At the core of the MLXLMCommon.generate workflow are two pivotal protocols: LogitProcessor and LogitSampler. While the sampler is responsible for the final selection of a token based on a probability distribution, the processor acts as a pre-sampling filter that modifies the raw scores, or logits, produced by the model's final linear layer.1

The LogitProcessor protocol is designed as a Sendable interface with a stateful lifecycle, comprising three essential requirements that allow for sophisticated state-machine-based masking 1:

1. **mutating func prompt(\_ prompt: MLXArray)**: This method is invoked once before token generation commences. It receives the tokenized representation of the initial prompt, enabling the processor to ingest the context and initialize its internal state machine or finite state automaton (FSA) based on the structural expectations established in the system prompt.1  
2. **func process(logits: MLXArray) \-\> MLXArray**: This functional hook is called at every inference step. It accepts the MLXArray of raw logits and returns a modified version. In the context of constrained decoding, this is where a binary mask is applied. Tokens that would violate the current grammar state are assigned a value of ![][image1], effectively setting their selection probability to zero.1  
3. **mutating func didSample(token: MLXArray)**: After the LogitSampler has selected a token y, the processor is notified via this callback. This feedback loop is critical for grammar engines, as it allows the processor to transition its state (e.g., moving to the next character in a JSON schema or exiting a quoted string block).1

The mathematical representation of this modification is straightforward yet powerful. If ![][image2] represents the original logit vector and ![][image3] represents the mask vector where ![][image4] for valid tokens and ![][image5] for invalid tokens, the modified logit vector ![][image6] is calculated as:

![][image7]  
This ensures that when the softmax function is applied to generate the probability distribution ![][image8], the probability of an invalid token becomes:

![][image9]

## **Integration within GenerateParameters and TokenIterator**

The GenerateParameters struct acts as the configuration hub for these interventions.1 It includes a processor() factory method that evaluates active penalties and returns a composite LogitProcessor, typically a PenaltyProcessor.1 This composite processor chains together several standard implementations, including the RepetitionContext, PresencePenaltyContext, and FrequencyPenaltyContext, applying them in the sequence established by the mlx-lm Python reference.1

The TokenIterator represents the concrete implementation of the generation loop. It is significant to note that the TokenIterator provides a public initializer that allows for the direct injection of a custom LogitProcessor and LogitSampler.1 This design confirms that developers can implement a GrammarConstrainedGenerator by passing a custom processor that encapsulates an EBNF compiler or a JSON schema validator without modifying the underlying MLXLMCommon source code.1

## **Evaluation of the mlx-swift-structured Library**

A critical question for the implementation of structured output is the existence of a usable Swift-native library. Research confirms that while the user query mentioned nicholasgasior/mlx-swift-structured, the community-recognized implementation is mlx-swift-structured authored by Ivan Petrukha (@petrukha-ivan), a contributor at MacPaw.3 This library is specifically designed to provide structured output generation using constrained decoding within the MLX Swift environment.3

## **Library Status and Core Features**

The mlx-swift-structured library is currently in a usable state and has been demonstrated to solve the reliability issues inherent in smaller models, such as the Qwen 3 series.4 It addresses the tendency of models like Qwen 3 1.7B or Llama 3.2 1B to deviate from system instructions and produce conversational text instead of the required tool-call format.4

The library introduces a Domain Specific Language (DSL) for grammar construction, which is more idiomatic for Swift developers than raw EBNF strings. Key components of this DSL include:

| Component | Description | Application |
| :---- | :---- | :---- |
| **SequenceFormat** | A linear sequence of expected formats. | Defining the overall flow of a response (e.g., thinking block followed by JSON).4 |
| **TagFormat** | Enforces start and end tags. | Guarantees the presence of \<think\> or \<tool\_call\> markers.4 |
| **TriggeredTagsFormat** | Conditional enforcement based on a trigger. | Ensuring tool calls are valid only after a specific token sequence appears.4 |
| **AnyTextFormat** | Allows unconstrained generation within a block. | Used inside reasoning or thinking blocks where creativity is desired.4 |

A significant insight from the library's implementation is its use of a structured sampler that can be applied to the entire output or specific branches of the logic.4 This avoids the need to swap the logit processor during generation; instead, the grammar rules themselves define where constraints are active and where the model is allowed "free-form" generation.4

## **Synergy with Apple's Foundation Models Framework**

The utility of mlx-swift-structured is significantly amplified by its integration with Apple's latest Foundation Models framework, introduced in macOS 15 and iOS 18 (Tahoe).6 The framework provides a @Generable macro that ensures type-safe structured output for Apple's on-device models. By bridging these schemas—which are exportable as JSON—to mlx-swift-structured, developers can maintain a single definition for structured data that works across both Apple's proprietary foundation models and open-weight models running on MLX.6

This bridge enables a "schema-first" development pattern:

1. Define a Swift struct and conform it to the Generable and Decodable protocols.6  
2. Use the @Generable macro to generate the required metadata.  
3. Pass the resulting JSON schema to the mlx-swift-structured grammar engine to create a logit mask for the MLX model.6

## **Formal Grammar and JSON Schema Constraint Logic**

Constrained decoding is essentially an intersection between the high-dimensional vector space of a transformer model and the discrete, formal rules of a grammar. To implement a GrammarConstrainedGenerator, one must understand how high-level constraints like JSON schemas are translated into the low-level token masks required by the LogitProcessor.

## **JSON Schema Benchmarking and Efficiency**

The adoption of JSON Schema as the primary format for structured output has led to the development of benchmarks like JSONSchemaBench, which consists of 10,000 real-world schemas.7 Research indicates that constrained decoding frameworks vary significantly in their coverage of these schemas. A high-performance framework must support a wide range of JSON keywords, including type constraints, property requirements, and array length limits.7

Furthermore, constrained decoding has been observed to improve the quality of downstream tasks by up to 4%, even for tasks with minimal structural requirements like mathematical reasoning (GSM8k).7 This suggests that the "centering" effect of a grammar engine helps the model stay within the intended semantic domain, reducing the probability of divergent or hallucinatory branches.7

## **Transitioning from Prompts to Masks**

While naive prompting—asking the model to "output JSON with fields X, Y, and Z"—works for large models like GPT-4, it is brittle for the 1B to 7B models typically run on-device.4 The transition to hard logit masking provides several benefits:

| Benefit | Description | Impact on Integration |
| :---- | :---- | :---- |
| **Format Guarantee** | 100% validity of the JSON or XML structure. | Eliminates the need for "retry" loops and complex regex parsers.8 |
| **Type Enforcement** | Ensures booleans are true/false rather than "yes"/"no". | Direct compatibility with Swift Decodable types without custom CodingKeys.6 |
| **Interoperability** | Output is immediately usable by APIs and databases. | Seamless integration with tools like n8n or OpenCode.8 |
| **Deterministic Sampling** | Reducing temperature to 0.1-0.3 ensures consistent adherence. | More predictable behavior in multi-step agentic tasks.6 |

## **Subprocess Integration: The MoLoRA Pattern and Outlines**

If a native Swift implementation of a specific grammar is unavailable, the user query proposed using outlines-dev/outlines (Python) as a subprocess, similar to the MoLoRA pattern.3 This approach is increasingly viable due to the modernization of process management in Swift 6.2.

## **Swift 6.2 Subprocess Framework**

The legacy Process API (formerly NSTask) was often criticized for its reliance on Objective-C paradigms and its lack of support for contemporary concurrency models.12 The new Subprocess package introduced in Swift 6.2 provides a streamlined, async/await friendly interface for managing external tools.13

Key improvements in the Subprocess framework relevant to a Python bridge include:

* **Buffer Management**: Subprocess transparently handles large amounts of I/O, preventing the "deadlock" issues that occurred when the 64KiB pipe buffer was exceeded.13  
* **AsyncSequence Streaming**: Output can be collected as an AsyncSequence, allowing the Swift application to process tokens as they are generated by the Python subprocess.12  
* **Executable Discovery**: The framework allows launching executables by name without needing the full system path, simplifying the configuration of a Python environment.12

## **Feasibility of an Outlines Subprocess**

The outlines library is a dominant framework for constrained decoding in the Python ecosystem and has explicit support for MLX.4 Integrating outlines via a subprocess would involve creating an OutlinesConstrainedGenerator that communicates with a long-running Python process.

However, there are two potential architectures for this bridge:

1. **Full Inference Subprocess**: The entire MLX model runs in Python using outlines.models.mlx. The Swift app merely sends prompts and receives structured JSON. This is simple but separates the model from the native Swift UI and lifecycle management.  
2. **Logit-Mask Subprocess**: The Swift app runs the model natively but calls the Python subprocess at every step to receive a list of valid token IDs for the current grammar state. This maintains native control but introduces significant latency due to the inter-process communication (IPC) required for every single token.15

Given the performance of mlx-swift-structured and the overhead of IPC, the full inference subprocess (Architecture 1\) is the more practical "MoLoRA-style" alternative if native Swift logic is insufficient.3

## **Hardware Performance and Memory Management on Apple Silicon**

A critical consideration for on-device structured generation is the interplay between the logit processor's logic and the physical constraints of the Apple Silicon GPU. The MLX framework's efficiency is predicated on unified memory, but this shared pool also creates specific failure modes.

## **Memory Pressure and KV Cache**

Structured output generation, especially for large documents or complex tool calls, can lead to substantial growth in the Key-Value (KV) cache.1 The GenerateParameters struct provides several controls to mitigate this:

| Parameter | Function | Optimization Strategy |
| :---- | :---- | :---- |
| **maxKVSize** | Limits the sliding window of the cache. | Prevents OOM (Out-of-Memory) crashes during long JSON generations.1 |
| **kvBits** | Enables 4-bit or 8-bit cache quantization. | Reduces memory footprint by up to 50% on devices with 8GB or 16GB RAM.1 |
| **prefillStepSize** | Controls prompt processing batch size. | Balances initial latency with memory spikes during long schema ingestion.1 |

Research notes that MLX has a "tendency to hold on to memory," which can lead to app crashes after multiple queries if the GPU cache limit is not explicitly set.17 Developers should use MLX.GPU.set(cacheLimit:) to ensure stability, particularly when the LogitProcessor introduces additional computational overhead at each step.18

## **GPU Crash Mitigation**

When handling multiple simultaneous requests or very long context windows, the Metal GPU can run out of memory, resulting in a kernel panic.16 The signature of such a crash is typically EXC\_CRASH (SIGABRT) on com.Metal.CompletionQueueDispatch.16 To prevent this, constrained decoding implementations should:

* Set a reasonable maxTokens limit (e.g., 4096).  
* Avoid concurrent requests on devices with less than 32GB of unified memory.16  
* Use low temperatures (0.1-0.3) for structured tasks to minimize the exploration of complex, memory-intensive paths.6

## **Comparative Analysis of Model Architectures in Structured Tasks**

The selection of the underlying model is as important as the choice of the logit processor. Different architectures exhibit varying levels of "innate" adherence to structural rules, which affects the frequency with which the logit mask must intervene.

## **Qwen 3 and Qwen 3.5 Performance**

The Qwen series, particularly the 1.7B, 4B, and 7B variants, have emerged as the premier choice for structured tasks on Apple Silicon.6 Qwen 3.5 35B-A3B (MoE) is notably efficient, requiring only \~19GB of VRAM in 4-bit quantization while delivering generation speeds of \~60 tokens/second on M1 Ultra hardware.16

A unique challenge with the Qwen 3.5 series is its "overthinking" tendency. The model may generate extensive reasoning before providing the required JSON or XML.19 Developers often use the /nothink or \--no-think flag to disable this behavior, allowing the logit processor to focus purely on the structured payload.19 Furthermore, Qwen’s tool-calling format (typically XML) may not match the JSON-centric expectations of some frameworks, requiring the use of specialized processors like those found in afm-mlx or mlx-swift-structured to bridge the gap.4

## **Llama 3.2 and Gemma 3**

Llama 3.2 models are highly capable but can be less deterministic than Qwen without hard constraints.6 Gemma 3 models (especially the 4B and 27B variants) exhibit strong performance but may require more aggressive temperature management and specific system prompting to avoid straying from the schema.6

| Model | Size (4-bit) | Structured Capability | Recommended Logic |
| :---- | :---- | :---- | :---- |
| **Qwen 3.5 1.7B** | \~1.2 GB | Excellent | mlx-swift-structured with @Generable.6 |
| **Qwen 3.5 4B** | \~2.8 GB | Superior | Native LogitProcessor with JSON schema.16 |
| **Llama 3.2 3B** | \~2.1 GB | Good | Standard penalties \+ ArgMax sampler.6 |
| **Phi-4** | \~8.2 GB | Reliable | TokenIterator with custom grammar hook.18 |

## **Implementation Strategy for a GrammarConstrainedGenerator**

The research suggests a clear path for resolving the current "halt" and implementing the GrammarConstrainedGenerator. The recommended strategy involves three tiers of implementation, prioritized by native compatibility and performance.

## **Tier 1: Native Implementation via mlx-swift-structured**

The existence of mlx-swift-structured 3 confirms that a native Swift solution is the most efficient path. The developer should:

1. Add https://github.com/petrukha-ivan/mlx-swift-structured as a package dependency.  
2. Define the output schema using Swift Decodable types and Apple’s @Generable macro for parity with Foundation Models.6  
3. Wrap the library's Grammar DSL into a GrammarConstrainedGenerator class.  
4. Register this generator in the AppBootstrap phase by injecting it into the ModelContainer generation stream.

## **Tier 2: Custom Logit Masking via MLXLMCommon Hooks**

If the community library does not support a specific required EBNF feature, the developer can utilize the native LogitProcessor hooks discovered in the MLXLMCommon source.1

1. Implement a class conforming to LogitProcessor.  
2. In the process(logits:) method, apply a manual mask to the MLXArray.1  
3. Use the TokenIterator public initializer to supply this custom processor.1  
4. This approach allows for the implementation of a custom EBNF→logit mask compiler as originally envisioned.

## **Tier 3: Subprocess Bridge for Outlines**

If the complexity of the grammar requires the mature Python outlines engine, the new Swift 6.2 Subprocess framework should be used.12

1. Create an OutlinesConstrainedGenerator that launches a Python environment using Subprocess.Configuration.  
2. Use the MoLoRA pattern where the model runs in a separate process to avoid memory conflicts with the main Swift app.3  
3. Stream the output back via AsyncSequence to the Swift UI.12  
4. Note that this is restricted to macOS and cannot be used in sandboxed iOS applications.12

## **Strategic Recommendations and Outlook**

The transition to structured decoding is not merely a technical hurdle but a fundamental shift in how developers interact with local language models. By moving away from brittle, prompt-based structural requests and toward hard logit masking, applications gain the reliability required for industrial-strength AI integrations.

The MLX Swift ecosystem is well-positioned for this transition. The existence of the LogitProcessor protocol provides a clear, high-performance interface for interception, while community efforts like mlx-swift-structured provide the high-level abstractions necessary for developer productivity. The alignment with Apple's Foundation Models framework via the @Generable macro suggests a future where structured generation is a first-class citizen of the Apple development stack.

For immediate implementation, the priority should be placed on Tier 1 (native library usage). The ability to bridge Apple’s type-safe structures with MLX-optimized models like Qwen 3.5 4B provides a robust, future-proof architecture that minimizes overhead while maximizing the reliability of the generated data. This approach allows the "blocked" development to proceed with a clear understanding of the API hooks and the tools available to implement 100% reliable structured output.

#### **Works cited**

1. mlx-swift-lm/Libraries/MLXLMCommon/Evaluate.swift at main · ml ..., accessed March 24, 2026, [https://github.com/ml-explore/mlx-swift-lm/blob/main/Libraries/MLXLMCommon/Evaluate.swift](https://github.com/ml-explore/mlx-swift-lm/blob/main/Libraries/MLXLMCommon/Evaluate.swift)  
2. accessed March 24, 2026, [https://raw.githubusercontent.com/openclaw/skills/main/skills/ronaldmannak/mlx-swift-lm/skill.md](https://raw.githubusercontent.com/openclaw/skills/main/skills/ronaldmannak/mlx-swift-lm/skill.md)  
3. MLX Swift Community Projects \#152 \- GitHub, accessed March 24, 2026, [https://github.com/ml-explore/mlx-swift/discussions/152](https://github.com/ml-explore/mlx-swift/discussions/152)  
4. Suggestion: Structured Output (for Tool Usage) · Issue \#221 · ml-explore/mlx-swift-examples, accessed March 24, 2026, [https://github.com/ml-explore/mlx-swift-examples/issues/221](https://github.com/ml-explore/mlx-swift-examples/issues/221)  
5. petrukha-ivan \- GitHub, accessed March 24, 2026, [https://github.com/petrukha-ivan](https://github.com/petrukha-ivan)  
6. Exploring MLX Swift: Structured Generation with @Generable Macro \- Rudrank Riyam, accessed March 24, 2026, [https://rudrank.com/exploring-mlx-swift-structured-generation-with-generable-macro](https://rudrank.com/exploring-mlx-swift-structured-generation-with-generable-macro)  
7. Generating Structured Outputs from Language Models: Benchmark and Studies \- arXiv, accessed March 24, 2026, [https://arxiv.org/html/2501.10868v1](https://arxiv.org/html/2501.10868v1)  
8. Structured Output Generation in LLMs: JSON Schema and Grammar-Based Decoding | by Emre Karatas | Medium, accessed March 24, 2026, [https://medium.com/@emrekaratas-ai/structured-output-generation-in-llms-json-schema-and-grammar-based-decoding-6a5c58b698a6](https://medium.com/@emrekaratas-ai/structured-output-generation-in-llms-json-schema-and-grammar-based-decoding-6a5c58b698a6)  
9. GitHub \- scouzi1966/maclocal-api: 'afm' command cli: macOS server and single prompt mode that exposes Apple's Foundation and MLX Models and other APIs running on your Mac through a single aggregated OpenAI-compatible API endpoint. Supports Apple Vision and single command (non-server) inference with piping as well . Now with Web Browser and local AI API aggregator, accessed March 24, 2026, [https://github.com/scouzi1966/maclocal-api](https://github.com/scouzi1966/maclocal-api)  
10. Exploring MLX Swift: Working with Generate Parameters for Language Models, accessed March 24, 2026, [https://rudrank.com/exploring-mlx-swift-working-with-generate-parameters-for-language-models](https://rudrank.com/exploring-mlx-swift-working-with-generate-parameters-for-language-models)  
11. mlx-swift-examples/Tools/llm-tool/LLMTool.swift at main \- GitHub, accessed March 24, 2026, [https://github.com/ml-explore/mlx-swift-examples/blob/main/Tools/llm-tool/LLMTool.swift](https://github.com/ml-explore/mlx-swift-examples/blob/main/Tools/llm-tool/LLMTool.swift)  
12. Moving from Process to Subprocess \- TrozWare, accessed March 24, 2026, [https://troz.net/post/2025/process-subprocess/](https://troz.net/post/2025/process-subprocess/)  
13. Blog \- Swift 6.2: Subprocess \- Michael Tsai, accessed March 24, 2026, [https://mjtsai.com/blog/2025/10/30/swift-6-2-subprocess/](https://mjtsai.com/blog/2025/10/30/swift-6-2-subprocess/)  
14. Blog \- Archive \- 2025 \- October \- Michael Tsai, accessed March 24, 2026, [https://mjtsai.com/blog/2025/10/](https://mjtsai.com/blog/2025/10/)  
15. \[Review\] SF-0007: Introducing Swift Subprocess \- Page 6 \- Foundation, accessed March 24, 2026, [https://forums.swift.org/t/review-sf-0007-introducing-swift-subprocess/70337?page=6](https://forums.swift.org/t/review-sf-0007-introducing-swift-subprocess/70337?page=6)  
16. I Replaced $100+/month in GEMINI API Costs with a €2000 eBay Mac Studio — Here is my Local, Self-Hosted AI Agent System Running Qwen 3.5 35B at 60 Tokens/Sec (The Full Stack Breakdown) : r/n8n \- Reddit, accessed March 24, 2026, [https://www.reddit.com/r/n8n/comments/1ri8922/i\_replaced\_100month\_in\_gemini\_api\_costs\_with\_a/](https://www.reddit.com/r/n8n/comments/1ri8922/i_replaced_100month_in_gemini_api_costs_with_a/)  
17. Building Offline RAG on iOS: How to Run Gemma 3N Locally | by Greg Sommerville | Google Cloud \- Medium, accessed March 24, 2026, [https://medium.com/google-cloud/building-offline-rag-on-ios-how-to-run-gemma-3n-locally-ffdfda6f7217](https://medium.com/google-cloud/building-offline-rag-on-ios-how-to-run-gemma-3n-locally-ffdfda6f7217)  
18. Running Phi models on iOS with Apple MLX Framework \- StrathWeb, accessed March 24, 2026, [https://www.strathweb.com/2025/03/running-phi-models-on-ios-with-apple-mlx-framework/](https://www.strathweb.com/2025/03/running-phi-models-on-ios-with-apple-mlx-framework/)  
19. afm mlx on MacOs \- new Version released\! Great new features (MacOS) : r/OpenSourceeAI, accessed March 24, 2026, [https://www.reddit.com/r/OpenSourceeAI/comments/1rx2btc/afm\_mlx\_on\_macos\_new\_version\_released\_great\_new/](https://www.reddit.com/r/OpenSourceeAI/comments/1rx2btc/afm_mlx_on_macos_new_version_released_great_new/)  
20. afm mlx on MacOs \- new Version released\! Great new features (MacOS) : r/LocalLLaMA, accessed March 24, 2026, [https://www.reddit.com/r/LocalLLaMA/comments/1rx2bhq/afm\_mlx\_on\_macos\_new\_version\_released\_great\_new/](https://www.reddit.com/r/LocalLLaMA/comments/1rx2bhq/afm_mlx_on_macos_new_version_released_great_new/)  
21. scousi \- Reddit, accessed March 24, 2026, [https://www.reddit.com/user/scousi/](https://www.reddit.com/user/scousi/)  
22. ml-explore/mlx-swift-lm \- GitHub, accessed March 24, 2026, [https://github.com/ml-explore/mlx-swift-lm](https://github.com/ml-explore/mlx-swift-lm)  
23. LLMBasic \- ml-explore/mlx-swift-examples \- GitHub, accessed March 24, 2026, [https://github.com/ml-explore/mlx-swift-examples/blob/main/Applications/LLMBasic/README.md](https://github.com/ml-explore/mlx-swift-examples/blob/main/Applications/LLMBasic/README.md)

[image1]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACIAAAAXCAYAAABu8J3cAAAA+klEQVR4XmNgGAWjYBSMgsEDqoB4ERC7oUsgAVcgXgbEaegS1AL/gfg8EN+DskHYDkleGSoGcoQ0ELsA8T8keaoAdAM5GRCOMQZiHihbBFkRFPxAFxAGYhMisTpUDwiAfJeBxIcBNgaEY0BYG1UaDvrQBeSB2I9IbAvVAwKJQMyNxEcGFgwIh+ACzkCsgC5IDjACYl10QShgZ0A45BGaHAzUADEjuiC54Dq6ABSAHOAExC+g7NWo0mCAL7RIBhVAHInEByVKkAUg38LAJ6jYQwZIetQC4q9A7IWkhirAnwERDe+AmBdVGgxA6esvA0KdDqr0KBgFo4A0AACCWTPVSKeTRwAAAABJRU5ErkJggg==>

[image2]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAoAAAAYCAYAAADDLGwtAAAAcElEQVR4XmNgGAW0AJZAvAyImaB8EJ2FkIaARCD+j4S9gfgnigoouIPG/w3EgmhiGOAMEEujC6KDR0DMhy6IDj4AMTO6IDr4hi7AAPEUCngCxJ+gEs+B+AqUHYusCMQBBQ0IgMLtLwNEURBcxSggBAD2SxWRkBoDXQAAAABJRU5ErkJggg==>

[image3]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABUAAAAYCAYAAAAVibZIAAABCUlEQVR4XmNgGAW0BvVA/AWI/0PxWVRpDPCQAaEWpK8YVRoVwBSCMC6gB8S1DBA1xmhyWMETBoSLcYHHQHyMAb8aOPAC4hQg3sKAW8M6KE3IN3BwAkqDwgebBh4gzoWyQfKrkeRwAphBoHACsWWQ5EDgB5R2Z4DIayHJ4QRPkdggTXFI/Hwg5oayQT7C5hMMALI9DYkP0rQQiY/sVZLDEwZAmkCxDALPkCUYIHKr0MSwAnSbYa6xBWIdJHFvqLg2khhO8BKN/4YBovk2mjgop6E7AAMwAvFdBki2QwbLGbBrJhiePUD8AYjfAvFnIP6DJOcDxKFI/K8MCLWfgPg3EFciyY+CUUALAABbjUmZS+msywAAAABJRU5ErkJggg==>

[image4]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADwAAAAYCAYAAACmwZ5SAAAB7UlEQVR4Xu2WyytFURTGF0qKkWSEPwCZKDMzIZSRzIxkJmRkIMqIjMyEvAaKElJSZgoTmZmI8ixF5FFCWF/77M466+5zuaV76nZ+9XXO/r51umvfvc+DKCYmJpMYYr2wvj0dBuMEzsmvxXX9wTgypsn0dMEqU5kTOwkojCrWIJmaapVFyRerXozRX6MYO7kif6XDuGTtUfKadDNCif20OLwATaxO1iaFF656x992QbpBL8faJOOXatNy4B1xP7omU8Dq9s6Rr4gsatDPjjbJ+BPatNhJ4r7EeYnIwJt3bCCTl4ssatDPhjbJ+FvatFyLcxR2iHEPK987x05w7YC/MsxaDNECa441y5oh89Ttw0VJyCbTj73dJPBPtAmwal1ijMJ5MZbbF5lrwkVkXgdRgH7WtEnG39UmsPevBYV4GoMbGZDJlpUHiim61xR62tYmGX9Km0CvmF3FWlal8Js9v0J4qYKdNJaCes1lSUFPYU/pdm2CWzW+I/f+xxeY/nPAKZkXf1RgsrqvGodHWWSaxaeiZIkcxeSvvKSVlcN6ZxWqLF3gd9FXnvCeSX0ij7MeWfde+CkyfKW0ifEr+bVPrA/WgMiB/iPSTR2ZHtZZD6z9YPy/jLImtZnJ2NU9C7gZDF5TR6xcHcTExMT8Bz+vKYrK/5YGnwAAAABJRU5ErkJggg==>

[image5]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAFUAAAAYCAYAAACLM7HoAAACOklEQVR4Xu2XTYhOYRTHj5QNUfKxmbKVwYatlYViYmUlZiM7IQspGluysFKKDNKUaawsUJqVSUrKxkLIZ/mq8ZlmfP3/7/Mc99zjucwML706v/p17z3nufd9n/M897n3igRBEATtog++g1+zN+rpH3ggVVuet7ueDixaKNrEcrhfUpsVLhcUeCzVjG3iERyRn7cJMmvhVnhBmgt2Pm9/NZuDzLW85fpYKtgsuD3vMz9ocv8DW+A5uNknDN3wCNznE01oIblOcr/L5MjHvF0jKb/E5DqdD/A5vCTVXXi01iIti/ckPVMWw9twWa1FgSdmnxflyCk74My8zxldmskT5QA80+Bp2A9PwhPwONzFk9rIVbjIxTiB2Ef+H8L93ir9nRc+YOHs22aOeZFT5tje6jqSnnnwoQ/+RVZOQgsfvCU+S+rnW6nXwjIHbvJBRddThRfTH3tqE5JyXHs8C+TfvmKtn4SWQ+5YmSbVBJrtcpZ+H1D8zNOLrYJLTXxdjnPBniq8I9iRibozndY2hnzAoHXw9VGmwz0+qDxzxy8lXeiOi/NLq/QDd+EXH+wQPvlA5jq8CA9L6vP7errFLTjDBznFWRB+dloGpFy80qhtkDRiY3Cuy3UCC+Gwi92Xek3OStV3LnFcSy/DK6ZNC47AKHwlaTG2I9YDN5pjjpK2fQPH4V6TJ77YnQQfsrzT2Ac+oFbX0y3mw9dSFVff2dvGQXjMB4PfQ2cpX46DPwRfsW5KYdEOgiAIgqnwDbTlmEI7c/18AAAAAElFTkSuQmCC>

[image6]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAA8AAAAXCAYAAADUUxW8AAAAmUlEQVR4XmNgGCpAC4i50QWJBf+B+DW6ILEApFkXXZAY4M8A0UwWOAvEU9EFiQUEbbUE4mVAzATlg+gsKPs9lMYKEhkgpsOwNxD/RFGBB9xB4/8GYkE0MaLAGSCWRhckBAyBeCO6IDHAFYi70cT60PhYgTkQvwRiXySxDCD+gsTHCUChygHEmxlQQ5wgsEPjg3IOutgoGHAAAPWbGwiKUoXlAAAAAElFTkSuQmCC>

[image7]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAmwAAAAuCAYAAACVmkVrAAAC0UlEQVR4Xu3dsY8VRRwH8AExQUEjCZJAR+xIMCFqpAA6IxXQEDo7Gg0aGhsJWJnoX6CdCQ10lFR0BKMmQCgoKGgspCKYmIgaYH7Zmdzc6Lu793K37+l9Pskvu/udN+/2ul92dvelBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACbzbY+AABgsfyc65M+BABgcTzvg/+pS7lu57qThiZ1ks9z3U3D537sxgAARrcrbZ6GrXqcJv/PW3M9SMN47AMAzN1PuY734X/ApIZrNW/kejcN83d3Y+Farj9zfdoPAADMy6yNz7zNet7flG3MP9MOZDvLNsa2tAMAAGO5mmt/2T+ShqtNY7uY67U+nMGsDdtfZRvzv2sHsqe5dpQxAIDRRRNyLtcPZf+D5cMrerjGerNOmOBZrgu57qfhHH5dPjyVWZuqX8o25sfSZ/Vb2d4qYwAAc/V3H4wslht/78MpzdJUfZjrbNmP+e137JuQAwCM6utcp/twZHGf2IE+zL7og8b7uU50FU1Vn71dJ0xQl0NDPFxQG7M/mjyyj5vj8E5aaugAADbMy7ne68Pi+z7oxI36a6nX64QJ9qbhqdT1MMtVsHbOZ+U4lmhfafLIPHAAAIzuShoeOHi1HB/N9dXS8CjiFRpxhe9gOT6Zlhqoy83+Wk37+RD38FX14YI9TdaeU/XkXzIAgHV3vWzr/VltA3IojfOC2Hrlqj2H7Wm4ryzEy2ynMU0TFb9qUP/mvSZvvyOu/NXP3Gzyt0oGALBh2uW+uML2UXMcahO1kaLpiSXZ6lSzH17KdbjLVrPR59yqDS8AwFzEMuW3fTiyetP/sWXpyqLJG8OXZXujDQEAxjTmlapJzqfhR9kXUbxc+GEfAgCM6VH65zIpAAALZFcab3kRAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAFgYLwCxKX8tXgO2NQAAAABJRU5ErkJggg==>

[image8]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAC8AAAAYCAYAAABqWKS5AAACFklEQVR4Xu2WPUgdQRSFD4kk0U5SiBCIQmxFsEmhgpUQCCSKKJYSUASxMopWgo1WkUCSLppGTJNOxFbEMoIgCsFOsPKHRI0g6r1vZnTfcebtPnYfgfA+ODBz7p2f3fnZBcr8P3SxkYImNkrJoqiFzZRcsxHig+gEpoHqXHRI3vfb7HxeiVbZzIB60RGbhXATZZ7D+L5J+vKz4lT0ms0QOpENNi2+B5sQbZKXJQ24P6aXXpjEDg4IlfBPXusvycsaHaOKTWYb9yfn+AETe0N+KN/xTjQjemTrQ6JPd+FE6BizbDK+N6u0w/hz5OtB9eU7LkUVomqYvD1RnWjYxpKi5+yCTcZN/hjmlP+19S3R00ieYwrhye+LnkTqmqer58o7kVgcXxAeJ4fb7/0cKMACwp2ORMoPYfJe2Hr0oRzzolY2LWMIj5NjFzEJHr4iWZv3iM+bZCPCKGLauy1TDONI1uYPkuWF+IyY9hr8xWYMbxHuVM/LN1vWnOjXuRt31+tj0U+YlQ+xIjpj06FLpgMMcCABvsnXwvh9oh5bnrexBzAr4XBlXz8OjenvSx4fRb9hbhb9j9FP8VVeRjzacTObwgHyJ61XndZ9X2/9DuiNEkLb6XWbOcuidTaLpNBbf4bC8dSk6VyvTbfabdGARXdFJ5tZMi1aYrMI9HDroWVqYLZfyVkTNbKZkjQrWjSDbKTAt4XK/HNuACS9h1I7v3u6AAAAAElFTkSuQmCC>

[image9]: <data:image/png;base64,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>