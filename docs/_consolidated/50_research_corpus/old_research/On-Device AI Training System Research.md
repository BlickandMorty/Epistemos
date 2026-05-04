# **Optimal Architecture for an On-Device Personal AI Training System with Automated Skill Generation**

The evolution of on-device Knowledge Fusion systems—particularly those leveraging the MLX framework on Apple Silicon to train highly quantized 4-bit language models—represents a critical paradigm shift in personalized artificial intelligence. Transitioning from a manual, user-configured QLoRA training pipeline to a fully automated, repository-aware system requires the integration of advanced static analysis, dynamic hyperparameter allocation, and intelligent context curation. As small parameterized models (0.8B to 9B parameters) exhibit unique sensitivities to data quality and context window optimization, the architecture must rigorously balance computational efficiency with representational expressivity. This comprehensive architectural blueprint establishes the algorithmic foundations for vault content analysis, the mathematical formulations for automated LoRA hyperparameter tuning, the structural specifications for AI-consumable skill generation, and the orchestration of retrieval-augmented system prompts.

## **Vault Content Analysis and Classification Algorithms**

To achieve a zero-configuration automated training mode, the system must independently evaluate the ingested vault to determine its intrinsic characteristics. This evaluation dictates the subsequent processing pipelines, synthetic data generation strategies, and hyperparameter assignments. Executing this analysis without invoking a Large Language Model is paramount to preserving local compute resources for the actual QLoRA fine-tuning phase.

## **Lightweight Heuristics for Document Classification**

The differentiation between prose, source code, technical documentation, and mixed-media relies on a bifurcated approach utilizing regular expressions for structural fingerprinting and lightweight natural language processing for semantic evaluation.1 Regular expressions provide highly efficient, deterministic pattern matching, specifically for identifying boilerplate code, import statements, and generated file headers.3 A file is classified as source code if it exhibits a high density of language-specific keywords, syntactical operators, and standard import paradigms, whereas prose is identified by a high density of standard punctuation, longer paragraph structures, and the absence of programmatic indentation.

Technical documentation occupies a hybrid space, identified by the presence of structured markdown elements interspersed with high-density prose.5 A deterministic scoring mechanism evaluates the ratio of code-block tokens to prose tokens to classify the document accurately. Documents with an intermediate ratio are classified as technical documentation, triggering a hybrid training profile that balances stylistic adaptation with factual memorization.

| Document Classification | Primary Detection Heuristics | Code-to-Prose Token Ratio | Expected Vault Characteristics |
| :---- | :---- | :---- | :---- |
| **Prose / Notes** | High punctuation density, sentence boundary markers, lack of indentation blocks. | ![][image1] | High narrative flow, subjective tone, conceptual linking. |
| **Source Code** | Syntax operators (-\>, \=\>, ::), high frequency of reserved keywords, block indentation. | ![][image2] | Rigid structure, deterministic logic, high repetition of variable names. |
| **Technical Docs** | Markdown headers (\#, \#\#), fenced code blocks (\`\`\`), API endpoint references. | ![][image3] | Structured explanations, isolated code snippets, highly instructional tone. |
| **Mixed Media** | Rapid alternation between standard paragraphs and tabular or code data. | Highly Variable | Requires chunk-level classification rather than file-level classification. |

## **Token Estimation Heuristics Without Tokenization**

Accurate token estimation is critical for calculating training iterations, defining sequence lengths, and allocating memory budgets on Apple Silicon without incurring the computational overhead of full tokenization passes across large personal vaults.6 Empirical studies indicate that deterministic mathematical heuristics can approximate modern subword tokenization with high fidelity.

The baseline heuristic for modern subword tokenizers establishes that one token is roughly equivalent to 3.5 English characters, accounting for varying word lengths and punctuation.8 Alternatively, when analyzing text at the word boundary level, approximately 750 words equate to 1000 tokens, yielding a multiplier of 1.33 tokens per word.9 To estimate the total training tokens within a vault robustly, the system employs a dual-bound calculation formula that accommodates both character-dense code repositories and word-dense prose vaults. The total tokens can be approximated by calculating the maximum value between the character-based estimate and the word-based estimate for each document, summing these values across the entire corpus. This ensures that a repository heavy in compressed mathematical syntax is not underestimated, while a vault full of verbose narrative is not overestimated.

## **Vocabulary Richness and Intrinsic Dimensionality**

Predicting the optimal LoRA rank requires a deep understanding of the complexity and intrinsic dimensionality of the training data. Standard metrics like the Type-Token Ratio are fundamentally flawed for this purpose, as they are highly sensitive to document length and degrade as the corpus scales.10 Instead, the architecture relies on the Measure of Textual Lexical Diversity (MTLD), a robust metric that remains stable across varying text lengths.10

High lexical diversity directly correlates with higher intrinsic dimensionality in the semantic feature space.12 Texts with high intrinsic dimensionality, such as creative prose or nuanced architectural documentation, require a larger parameter space to capture their underlying manifold effectively. Conversely, low intrinsic dimensionality texts, such as repetitive code structures or strict scientific formatting, can be compressed into a lower-rank space without losing fidelity.12

The system calculates MTLD using a moving average bi-directional algorithm.14 This algorithmic approach computes the lexical diversity score by evaluating sequences in both forward and backward passes across a sliding window, wrapping around the text to complete the final factors.14 This ensures that structural anomalies at the beginning or end of a file do not skew the metric. The resulting bidirectional MTLD score acts as a direct mathematical proxy for the dataset's intrinsic dimensionality, informing the automated selection of the LoRA rank matrix.

## **Data-Aware Hyperparameter Auto-Tuning Architecture**

Transitioning to a fully automated training pipeline requires mathematical models capable of dynamically selecting hyperparameters based on the calculated characteristics of the personal vault. Small datasets, specifically those ranging from 50 to 500 examples, present significant challenges, primarily the high risk of catastrophic overfitting, loss of generalization, and model collapse.15

## **Geometric Low-Rank Adaptation and Rank Selection**

Rather than utilizing a static, hardcoded rank parameter, the architecture employs principles derived from Geometric Low-Rank Adaptation and Data-Aware LoRA initialization.16 These frameworks demonstrate mathematically that the intrinsic dimension of the data representations serves as a lower bound for the optimal rank of the LoRA matrices.16

The data-aware initialization framework minimizes the discrepancy between the fine-tuned and target models by accounting for the non-isotropic nature of representations in transformer architectures.17 It achieves this by utilizing the Fisher Information Matrix, which measures the model's sensitivity to perturbations in different parameter directions.17 The algorithm estimates the Fisher matrix using Kronecker-factored Approximate Curvature on a small sample of the target domain, allowing the system to determine which parameter directions contain the most critical information.17 By correlating the MTLD score with the estimated Fisher Information Matrix, the system calculates a mathematically sound base rank. For vaults classified as prose with high lexical diversity, the algorithm scales the rank logarithmically to capture stylistic nuances. For structured knowledge profiles, the rank is constrained to prevent the memorization of arbitrary syntax.

## **Hyperparameter Formulas for Small Corpora**

Training stability is paramount for on-device personal vaults yielding a limited number of instruction-response pairs. The system applies specific auto-tuning heuristics and mathematical formulas to configure the MLX training environment optimally.

| Hyperparameter | Auto-Tuning Formula / Heuristic | Justification for Small Datasets (50-500) |
| :---- | :---- | :---- |
| **LoRA Rank (![][image4])** | **![][image5]** | Balances representational capacity against memory limits based on intrinsic dimensionality.15 |
| **LoRA Alpha (![][image6])** | **![][image7]** (Aggressive) or ![][image8] (Standard) | Ensures the fine-tuned adjustments carry sufficient weight over the pre-trained parameters.15 |
| **Epochs / Iterations** | $Epochs \= \\max(1, \\min(3, \\lfloor 500 / | D |
| **Batch Size** | Effective Batch Size \= 16 (Physical 2 ![][image9] Accumulation 8\) | Maximizes gradient stability on small datasets while respecting Apple Silicon VRAM constraints.15 |
| **Weight Decay** | **![][image10]** | Crucial regularization mechanism to prevent the model from memorizing specific training pairs.15 |

## **Scaling Laws and Learning Rate Warmup**

The relationship between model size, LoRA rank, and dataset size follows a predictable scaling law that governs the learning trajectory.19 The mutual information upper bound modeling the dependency between the pre-trained large language model and the LoRA modules dictates how quickly the model can safely absorb new domain knowledge.19 This formula allows the system to dynamically adjust the learning rate warmup phase.

For small personal corpora, a standard linear warmup followed by cosine decay is required to navigate the highly quantized 4-bit loss landscape. When the dataset size approaches the lower bound of 50 examples, the learning rate must peak rapidly within the first 5% to 10% of total training steps, utilizing a steep cosine decay schedule over the remaining steps to stabilize the gradients. For larger vaults approaching 500 examples, a gentler warmup phase extending up to 15% of the total steps is implemented, allowing the model to establish stable descent trajectories before the learning rate diminishes.

Detecting overfitting without a traditional validation set is achieved through continuous monitoring of the gradient norm and the variance of the training loss. If the training loss plateaus while the gradient norm spikes, or if the exponential moving average of the loss begins to exhibit high-frequency oscillation, the system triggers an early stopping mechanism, finalizing the adapter weights at the most stable preceding checkpoint.

## **Code Repository Analysis and Pattern Extraction**

Rendering the artificial intelligence genuinely repository-aware requires moving beyond semantic text processing to perform rigorous static analysis on source code files. This deep structural understanding enables the extraction of overarching architectural philosophies, error-handling heuristics, and API tool registries, transforming the system into a bespoke coding assistant.

## **Abstract Syntax Trees over Regular Expressions**

While regular expressions are highly effective for flat, deterministic data extraction such as identifying import statements or file headers, they are fundamentally inadequate for parsing nested logical structures and are highly susceptible to variations in whitespace, line breaks, and developer idiosyncrasies.2 The optimal architecture utilizes Tree-sitter, an advanced incremental parsing library that constructs precise Abstract Syntax Trees from source code across multiple language bindings.21

Tree-sitter queries operate using a Lisp-like S-expression syntax to traverse the Abstract Syntax Tree, allowing developers to extract specific nodes and their relationships regardless of superficial formatting.22 This mechanism empowers the RepoAnalyzer algorithm to safely and consistently extract complex function signatures, parameter type definitions, and return values across Swift, Python, Rust, JavaScript, and TypeScript with millisecond latency.22 By mapping these extractions directly to standard JSON Schema or OpenAPI specifications, the system automatically generates highly accurate tool-call training pairs.

## **Extracting Error Handling and Defensive Coding Styles**

A core capability of the RepoAnalyzer is deducing a developer's specific defensive coding style and error-handling preferences. Different repositories handle failures using vastly different paradigms, from strict monads to traditional exception bubbling. In Swift, for example, error handling frequently involves do-try-catch blocks and specific conformance to the Error protocol.24

The system deploys targeted Tree-sitter queries designed to capture function declarations alongside their associated error-handling blocks. By isolating the specific syntax of a catch block, the system can determine whether the user prefers localized string descriptions, generic error propagation, or custom enum-based error routing.24 These extracted structural snippets are then analyzed to synthesize a definitive error-handling skill file, guaranteeing that any newly generated code adheres strictly to the user's historical paradigms rather than falling back on the base model's generic tendencies.

## **Architectural Pattern Detection Heuristics**

Detecting higher-level macro-architectural patterns, such as Model-View-Controller (MVC), Model-View-ViewModel (MVVM), or Clean Architecture, requires analyzing the project's macro-structure, including file paths, naming conventions, and cross-file dependency graphs.25

The detection algorithm applies a multi-layered heuristic approach. If the Abstract Syntax Tree identifies a Swift file defining a class appended with ViewModel that imports reactive frameworks like Combine or Observation, and the directory structure reveals a corresponding View struct in an adjacent presentation folder, the system affirmatively registers an MVVM pattern.26 Consequently, it generates a strict skill file defining the separation of concerns, explicitly instructing the model that network calls and business logic must reside exclusively within the ViewModel, while the View remains functionally stateless. Similarly, the detection of UseCase, Repository, or Interactor file suffixes triggers the generation of Clean Architecture dependency rules, preventing the AI from suggesting tightly coupled database calls directly from user interface components.25

## **Training Data Quality and Boilerplate Filtering**

Generating high-quality instruction-response pairs from source code requires aggressive filtering of low-value, repetitive data. Training an adapter on extensive lists of standard import statements or heavily minified, auto-generated user interface layout coordinates severely degrades the model's reasoning capacity and wastes the limited parameter budget.4

The system employs regex and structural fingerprinting to detect and discard auto-generated code, massive test fixtures, and repetitive dependency declarations.3 By pruning these nodes via Abstract Syntax Tree manipulation prior to the synthetic data generation phase, the resulting instruction-response pairs focus exclusively on logic, bespoke architectural implementations, and proprietary algorithmic design. Furthermore, research indicates that "code explanation" training pairs—where the model is prompted to explain the extracted code block—are significantly more effective for teaching coding style and underlying logic than simple "code completion" pairs, which tend to encourage rote memorization over semantic understanding.

## **Negative Example Generation for Tool-Use Training**

A pervasive vulnerability in agentic language models, particularly when fine-tuned for tool usage on small datasets, is the propensity to hallucinate tool calls or utilize external tools when native deductive reasoning would suffice.29 Standard fine-tuning pipelines generally discard failed trajectories, an approach that inadvertently restricts the model's optimization pathways and fails to define the negative boundaries of tool usage.30 To prevent tool forgetting and mitigate hallucination, the repository-aware training pipeline must generate synthetic hard negative examples.

## **Adversarial Mutation Strategies**

The system employs an automated adversarial reinforcement learning framework to generate deceptively similar, yet functionally incorrect, code pairs.31 Initially, rule-based mutations are applied to verified, correct code extracted directly from the user's vault. These heuristic mutations include variable swapping, off-by-one adjustments to loop parameters, and operator toggling.31 These mechanically flawed snippets are paired with instructions demanding the model identify the error, effectively teaching the model what poor execution looks like within the specific context of the user's repository.

## **Discriminator and Edit Distance Rewards**

To transcend basic rule-based errors and generate truly "hard" negatives that rigorously test the model's boundaries, the framework utilizes a generator-discriminator architecture driven by Proximal Policy Optimization.31 The reward function guiding this generation is governed by three primary mathematical components.

First, a unit test reward subjects the generated code to local static analysis; if the code passes without error, it is heavily penalized, ensuring the negative example is genuinely flawed.31 Second, a discriminator reward provides positive reinforcement to the generator when it successfully fools the discriminator into classifying the buggy code as correct.31 Finally, an edit distance reward incentivizes minimal deviations from the original positive code, preventing the generator from outputting easily identifiable syntax errors or irrelevant characters.31

These adversarial negative examples are injected into the QLoRA training dataset alongside the positive tool-call examples. This contrastive learning methodology provides the highly quantized model with explicit behavioral boundaries, significantly reducing the action error rate during complex, multi-hop reasoning tasks and ensuring tools are only invoked when mathematically or logically necessitated.29

## **Skill File Generation Architecture**

Following the successful fusion of local knowledge into the QLoRA adapter, the system must translate the extracted domain constraints, architectural patterns, and writing voices into discrete, AI-consumable files. These "Skill Files" dynamically inject behavioral rules into the system prompt at inference time, bridging the gap between static weights and dynamic context.

## **Optimal Format Specification**

Extensive evaluations of nested data formats—including JSON, YAML, XML, and Markdown—across various language models reveal distinct variations in token efficiency, parsing latency, and instruction-following accuracy.32 Markdown consistently emerges as the most token-efficient format, consuming significantly fewer tokens than JSON and YAML while maintaining high structural legibility for causal language models.32

The optimal architecture for a skill file utilizes a hybrid approach: strict YAML frontmatter for programmatic metadata, versioning, and router ingestion, coupled with a dense Markdown body for the actual system prompt injection.33

| File Component | Format Standard | Purpose and Guidelines | System Constraints |
| :---- | :---- | :---- | :---- |
| **Metadata** | YAML | System routing, dependency tracking. | Name must be under 64 characters, utilizing gerund form (e.g., generating-views). |
| **Description** | YAML | Retrieval embeddings and semantic matching. | Written in the third person, tightly constrained under 1024 characters.33 |
| **Directives** | Markdown | Behavioral constraints and operational logic. | Employs a strict imperative tone, structured with logical heading hierarchies. |
| **Examples** | Markdown | Few-shot in-context learning. | Provides specific Input/Output pairs utilizing fenced code blocks. |

## **Granularity and Progressive Disclosure**

A critical design pattern for skill file generation is "progressive disclosure," which directly addresses the cognitive limitations of language models.33 Rather than generating a single monolithic mega-file that rapidly depletes the model's attention budget and exacerbates context rot, the system generates hierarchically structured, granular files.

The primary skill file must remain under a strict 500-line threshold to ensure optimal inference performance.33 When extracted domain concepts or coding conventions exceed this threshold, the engine automatically bundles additional reference files within the skill's dedicated directory structure.33 Crucially, references to these subsidiary files are kept strictly one level deep; deeply nested file hierarchies frequently cause the language model to halt its ingestion prematurely, resulting in partial context loads and erratic behavior.33

## **Instruction Following in 3B-9B Models**

Smaller parameterized models operating in the 3B to 9B range exhibit unique instruction-following behaviors compared to massive frontier models. While large models can often extrapolate intended behavior from abstract guidelines, smaller models benefit exponentially from high-quality, few-shot examples embedded directly within the skill file.34

To prevent systemic issues such as "over-triggering" or "under-triggering" of tools—a common phenomenon where smaller models merely suggest code modifications rather than executing a file write—the skill files must employ explicit XML-tagged behavioral overrides.36 The generator automatically injects strict tags encapsulating explicit commands that force the model to favor immediate tool execution over passive recommendations, effectively overriding the base model's conversational defaults.36

## **System Prompt Composition and Context Optimization**

As the personal vault scales and the repository of generated skill files expands, injecting all available guidelines, coding philosophies, and tool registries into the context window becomes computationally prohibitive and architecturally flawed. The system must orchestrate a dynamic composition engine to manage this influx of data.

## **The Ranking Versus Stuffing Paradigm**

Transformer-based models suffer from a fundamental constraint known as the "Quadratic Wall." Because the self-attention mechanism must compute similarity scores between every single pair of tokens, latency and compute costs scale quadratically as the context window expands.37 Furthermore, language models reliably experience the "lost in the middle" phenomenon, where critical instructions buried deep within massive system prompts are systematically ignored or degraded.38

Consequently, naive Retrieval-Augmented Generation approaches—which rely on prompt stuffing based on simple cosine similarity—are discarded. Instead, the architecture relies on a sophisticated dynamic ranking and pruning algorithm designed to maximize context utility while minimizing token payload.37

## **Multi-Retriever Fan-Out and Machine Learning Scoring**

To construct the optimal system prompt dynamically at inference time, the architecture deploys a multi-retriever pipeline that evaluates the user's immediate query against the entire library of generated skill files.37

The retrieval phase utilizes a fan-out approach, combining semantic vector search via localized embeddings with lexical keyword matching utilizing algorithms similar to BM25 to ensure high recall.37 These candidate files are subsequently evaluated by an ultra-lightweight ranking model, such as a locally executed LightGBM ensemble or a specialized cross-encoder.37

The learning-to-rank scoring algorithm assigns absolute relevance based on a weighted matrix of features. These features include the semantic cosine distance between the query vector and the skill file's description, contextual recency prioritizing skills utilized in the preceding interaction turns, and strict file type constraints that heavily weight specific syntax guidelines if the user query references a specific file extension.37

## **Priority Ordering and Context Pruning**

Following the scoring phase, the algorithm applies a diversity reordering penalty to ensure the selected skills provide orthogonal value, preventing the context window from being flooded with redundant instructions from identical document clusters.37 The system then rigorously prunes the candidate list, selecting only the highest-ranked skill files until a strict, pre-defined token budget is reached.37

Priority ordering is mathematically enforced during final string composition. System-critical components, such as tool registries and absolute security guardrails, are permanently pinned to the absolute top and bottom of the system prompt, exploiting the model's tendency to pay the highest attention to the initial and final tokens.38 Domain concept glossaries and specific writing profiles are dynamically swapped into the lower-priority middle tiers of the prompt based solely on the machine learning scoring.42 This rigorous architectural orchestration reduces the context payload by an order of magnitude, preserving the language model's attention budget for complex reasoning over the actual user query while maintaining exceptionally high task accuracy.37

## **Priority-Ordered Implementation Roadmap**

To transition the existing macOS application toward this optimal architecture while maximizing immediate user impact and ensuring system stability on Apple Silicon, the development lifecycle must follow a strict, phased implementation roadmap.

**Phase 1: The Vault Analyzer and Auto-Tuning Engine**

The immediate priority is replacing manual user configuration with the zero-configuration automated pipeline. This requires the implementation of the dual-bound token estimation heuristics and the moving average bi-directional MTLD algorithm. Following this, the integration of the LoRA-DA initialization logic via Fisher Information estimation will automate rank selection based on vault density. Finally, the deployment of the automated batch size and learning rate warmup formulas will stabilize small-dataset QLoRA training within the MLX environment.

**Phase 2: The Skill Generation and Composition Framework**

Once training is automated, the system must be capable of persisting extracted knowledge. This phase standardizes the output of the synthetic data pipeline to emit YAML/Markdown structured skill files upon training completion. It requires implementing the 500-line limit and progressive disclosure file bundling logic. Crucially, this phase introduces the Multi-Retriever Machine Learning Scoring system to dynamically rank, prune, and inject skill files into the MLX inference context window without breaching established token budgets.

**Phase 3: Repository-Aware Static Analysis and Adversarial Training**

The final phase elevates the system from a localized text-processor to a robust, repository-aware coding assistant. This requires integrating the Tree-sitter library with language bindings for Swift, Python, Rust, JavaScript, and TypeScript. Developers will construct S-expression queries to extract architectural patterns, function signatures, and error-handling paradigms. Concurrently, the adversarial rule-based mutation engine will be built to generate hard negative examples, integrating them into the synthetic data curator to prevent tool hallucination and ensure strict adherence to the user's proprietary codebase.

#### **Works cited**

1. Towards Reliable LLM Grading Through Self-Consistency and Selective Human Review: Higher Accuracy, Less Work \- MDPI, accessed March 24, 2026, [https://www.mdpi.com/2504-4990/8/3/74](https://www.mdpi.com/2504-4990/8/3/74)  
2. LLMs vs regex : r/Rag \- Reddit, accessed March 24, 2026, [https://www.reddit.com/r/Rag/comments/1n2osy1/llms\_vs\_regex/](https://www.reddit.com/r/Rag/comments/1n2osy1/llms_vs_regex/)  
3. re — Regular expression operations — Python 3.14.3 documentation, accessed March 24, 2026, [https://docs.python.org/3/library/re.html](https://docs.python.org/3/library/re.html)  
4. Some notes and tools on fingerprinting minified JavaScript libraries, AST fingerprinting, source code similarity, etc \- GitHub Gist, accessed March 24, 2026, [https://gist.github.com/0xdevalias/31c6574891db3e36f15069b859065267](https://gist.github.com/0xdevalias/31c6574891db3e36f15069b859065267)  
5. The RAG Engineer's Guide to Document Parsing : r/LangChain \- Reddit, accessed March 24, 2026, [https://www.reddit.com/r/LangChain/comments/1ef12q6/the\_rag\_engineers\_guide\_to\_document\_parsing/](https://www.reddit.com/r/LangChain/comments/1ef12q6/the_rag_engineers_guide_to_document_parsing/)  
6. Calculating LLM Token Counts: A Practical Guide \- Winder.AI, accessed March 24, 2026, [https://winder.ai/calculating-token-counts-llm-context-windows-practical-guide/](https://winder.ai/calculating-token-counts-llm-context-windows-practical-guide/)  
7. johannschopplich/tokenx: Fast token estimation at 96% accuracy of a full tokenizer in a 2kB bundle \- GitHub, accessed March 24, 2026, [https://github.com/johannschopplich/tokenx](https://github.com/johannschopplich/tokenx)  
8. Counting Claude Tokens Without a Tokenizer | by Peta Muir \- GoPenAI, accessed March 24, 2026, [https://blog.gopenai.com/counting-claude-tokens-without-a-tokenizer-e767f2b6e632](https://blog.gopenai.com/counting-claude-tokens-without-a-tokenizer-e767f2b6e632)  
9. LLM Cost Estimation Guide: From Token Usage to Total Spend | by Alpha Iterations, accessed March 24, 2026, [https://medium.com/@alphaiterations/llm-cost-estimation-guide-from-token-usage-to-total-spend-fba348d62824](https://medium.com/@alphaiterations/llm-cost-estimation-guide-from-token-usage-to-total-spend-fba348d62824)  
10. Relationships Between Text Length and Lexical Diversity Measures \- Castledown, accessed March 24, 2026, [https://www.castledown.com/journals/vli/article/view/vli.v01.1.koizumi/213](https://www.castledown.com/journals/vli/article/view/vli.v01.1.koizumi/213)  
11. LexDive, version 1.3 A program for counting lexical diversity Developed by Łukasz Stolarski, December 2020 email, accessed March 24, 2026, [https://lexdive.pythonanywhere.com/static/readme/readme.pdf](https://lexdive.pythonanywhere.com/static/readme/readme.pdf)  
12. Unveiling Intrinsic Dimension of Texts: from Academic Abstract to Creative Story \- arXiv.org, accessed March 24, 2026, [https://arxiv.org/html/2511.15210v1](https://arxiv.org/html/2511.15210v1)  
13. Unveiling Intrinsic Dimension of Texts: from Academic Abstract to Creative Story \- ACL Anthology, accessed March 24, 2026, [https://aclanthology.org/2026.eacl-long.370.pdf](https://aclanthology.org/2026.eacl-long.370.pdf)  
14. kristopherkyle/lexical\_diversity: This is a simple Python ... \- GitHub, accessed March 24, 2026, [https://github.com/kristopherkyle/lexical\_diversity](https://github.com/kristopherkyle/lexical_diversity)  
15. LoRA fine-tuning Hyperparameters Guide | Unsloth Documentation, accessed March 24, 2026, [https://unsloth.ai/docs/get-started/fine-tuning-llms-guide/lora-hyperparameters-guide](https://unsloth.ai/docs/get-started/fine-tuning-llms-guide/lora-hyperparameters-guide)  
16. GeLoRA: Geometric Adaptive Ranks For Efficient LoRA Fine-tuning ..., accessed March 24, 2026, [https://aclanthology.org/2025.findings-emnlp.1372/](https://aclanthology.org/2025.findings-emnlp.1372/)  
17. LoRA-DA: Data-Aware Initialization for Low-Rank Adaptation ... \- arXiv, accessed March 24, 2026, [https://arxiv.org/abs/2510.24561](https://arxiv.org/abs/2510.24561)  
18. GeLoRA: Geometric Adaptive Ranks For Efficient LoRA Fine-tuning \- arXiv, accessed March 24, 2026, [https://arxiv.org/html/2412.09250v2](https://arxiv.org/html/2412.09250v2)  
19. The Scaling Law for LoRA Base on Mutual Information Upper Bound \- arXiv, accessed March 24, 2026, [https://arxiv.org/html/2501.03152v1](https://arxiv.org/html/2501.03152v1)  
20. Why use ast syntax tree modification instead of regex replacement? \- Stack Overflow, accessed March 24, 2026, [https://stackoverflow.com/questions/72017024/why-use-ast-syntax-tree-modification-instead-of-regex-replacement](https://stackoverflow.com/questions/72017024/why-use-ast-syntax-tree-modification-instead-of-regex-replacement)  
21. Tree-sitter: Introduction, accessed March 24, 2026, [https://tree-sitter.github.io/](https://tree-sitter.github.io/)  
22. Unraveling Tree-Sitter Queries: Your Guide to Code Analysis Magic \- DEV Community, accessed March 24, 2026, [https://dev.to/shrsv/unraveling-tree-sitter-queries-your-guide-to-code-analysis-magic-41il](https://dev.to/shrsv/unraveling-tree-sitter-queries-your-guide-to-code-analysis-magic-41il)  
23. VTCode/docs/user-guide/tree-sitter-integration.md at main \- GitHub, accessed March 24, 2026, [https://github.com/vinhnx/VTCode/blob/main/docs/user-guide/tree-sitter-integration.md](https://github.com/vinhnx/VTCode/blob/main/docs/user-guide/tree-sitter-integration.md)  
24. Swift do-try-catch syntax \- error handling \- Stack Overflow, accessed March 24, 2026, [https://stackoverflow.com/questions/30720497/swift-do-try-catch-syntax](https://stackoverflow.com/questions/30720497/swift-do-try-catch-syntax)  
25. MVVM as a complementary pattern for Clean Architecture applications \- Spaceteams, accessed March 24, 2026, [https://www.spaceteams.de/en/insights/mvvm-as-a-complementary-pattern-for-clean-architecture-applications](https://www.spaceteams.de/en/insights/mvvm-as-a-complementary-pattern-for-clean-architecture-applications)  
26. Android Architecture Patterns — MVC, MVP, MVVM, MVI, Clean Architecture | by Dashwave | DroidBlogs | Medium, accessed March 24, 2026, [https://medium.com/droidblogs/android-architecture-patterns-mvc-mvp-mvvm-mvi-clean-architecture-cde8029b8f37](https://medium.com/droidblogs/android-architecture-patterns-mvc-mvp-mvvm-mvi-clean-architecture-cde8029b8f37)  
27. Architecture Patterns for Beginners: MVC, MVP, and MVVM \- DEV Community, accessed March 24, 2026, [https://dev.to/chiragagg5k/architecture-patterns-for-beginners-mvc-mvp-and-mvvm-2pe7](https://dev.to/chiragagg5k/architecture-patterns-for-beginners-mvc-mvp-and-mvvm-2pe7)  
28. Regex to capture all import statements \- Stack Overflow, accessed March 24, 2026, [https://stackoverflow.com/questions/53632274/regex-to-capture-all-import-statements](https://stackoverflow.com/questions/53632274/regex-to-capture-all-import-statements)  
29. Learning From Failure: Integrating Negative Examples when Fine-tuning Large Language Models as Agents \- arXiv, accessed March 24, 2026, [https://arxiv.org/html/2402.11651v2](https://arxiv.org/html/2402.11651v2)  
30. Learning From Failure: Integrating Negative Examples when Fine-tuning Large Language Models as Agents \- arXiv, accessed March 24, 2026, [https://arxiv.org/html/2402.11651v1](https://arxiv.org/html/2402.11651v1)  
31. Adversarial RL for Hard-Negative Code ... \- Extended Abstract, accessed March 24, 2026, [https://cs224r.stanford.edu/projects/pdfs/CS\_224R\_Project1.pdf](https://cs224r.stanford.edu/projects/pdfs/CS_224R_Project1.pdf)  
32. Which Nested Data Format Do LLMs Understand Best? JSON vs. YAML vs. XML vs. Markdown \- Improving Agents, accessed March 24, 2026, [https://www.improvingagents.com/blog/best-nested-data-format/](https://www.improvingagents.com/blog/best-nested-data-format/)  
33. Skill authoring best practices \- Claude API Docs \- Claude Console, accessed March 24, 2026, [https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices)  
34. Instruction-Following Pruning for Large Language Models \- arXiv.org, accessed March 24, 2026, [https://arxiv.org/html/2501.02086v3](https://arxiv.org/html/2501.02086v3)  
35. Wow\! llama-3-8b's in-context learning is unbelievable : r/LocalLLaMA \- Reddit, accessed March 24, 2026, [https://www.reddit.com/r/LocalLLaMA/comments/1c7r2jw/wow\_llama38bs\_incontext\_learning\_is\_unbelievable/](https://www.reddit.com/r/LocalLLaMA/comments/1c7r2jw/wow_llama38bs_incontext_learning_is_unbelievable/)  
36. Prompting best practices \- Claude API Docs, accessed March 24, 2026, [https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices)  
37. Context Window Optimization: Why Ranking, Not Stuffing, Is the ..., accessed March 24, 2026, [https://www.shaped.ai/blog/context-window-optimization-why-ranking-not-stuffing-is-the-scaling-law-for-agents](https://www.shaped.ai/blog/context-window-optimization-why-ranking-not-stuffing-is-the-scaling-law-for-agents)  
38. Effective context engineering for AI agents \- Anthropic, accessed March 24, 2026, [https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)  
39. RAG vs. Prompt Stuffing: Overcoming Context Window Limits for Large, Information-Dense Documents \- Spyglass MTG, accessed March 24, 2026, [https://www.spyglassmtg.com/blog/rag-vs.-prompt-stuffing-overcoming-context-window-limits-for-large-information-dense-documents](https://www.spyglassmtg.com/blog/rag-vs.-prompt-stuffing-overcoming-context-window-limits-for-large-information-dense-documents)  
40. Advanced Retrieval Techniques in a World of 2M Token Context Windows: Part 2 on Re-rankers | Towards Data Science, accessed March 24, 2026, [https://towardsdatascience.com/advanced-retrieval-techniques-in-a-world-of-2m-token-context-windows-part-2-on-re-rankers-a0dfa03ba325/](https://towardsdatascience.com/advanced-retrieval-techniques-in-a-world-of-2m-token-context-windows-part-2-on-re-rankers-a0dfa03ba325/)  
41. Prune, Don't Just Re-Rank: The Secret to Cutting Hallucinations in Retrieval-Augmented Generation (RAG) \- Bhavik Jikadara, accessed March 24, 2026, [https://bhavikjikadara.medium.com/prune-dont-just-re-rank-the-secret-to-cutting-hallucinations-in-retrieval-augmented-generation-29840f8f725f](https://bhavikjikadara.medium.com/prune-dont-just-re-rank-the-secret-to-cutting-hallucinations-in-retrieval-augmented-generation-29840f8f725f)  
42. Prompt Engineering Is Dead, and Context Engineering Is Already Obsolete: Why the Future Is Automated Workflow Architecture with LLMs \- OpenAI Developer Community, accessed March 24, 2026, [https://community.openai.com/t/prompt-engineering-is-dead-and-context-engineering-is-already-obsolete-why-the-future-is-automated-workflow-architecture-with-llms/1314011](https://community.openai.com/t/prompt-engineering-is-dead-and-context-engineering-is-already-obsolete-why-the-future-is-automated-workflow-architecture-with-llms/1314011)

[image1]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADcAAAAXCAYAAACvd9dwAAABxUlEQVR4Xu2WTStFURSGl88opBQDA1OZ4gcoIwZm/AApxcDITJn7AxITM0QYmGBogkKJIUJRUshHPuJd7X20z7pnnY97u5Pbfurptt+1Ouese8/Z5xJ5PJ5SYgo+wzc4LGpp6INLMrR8wgnYAmthL7x0G4rJGdx21qdwz1lrTMIX+GtdDpf/CequPaGOPOiXQQQNZE4m4axRhjEkDTcN5+FQuJSdOfgF22UhgmPSh+OLSUvScAWzA59gsyzEENwmEi3XKMpwlWSemSsyD2tWtCG0XCNpOH6mb+GWXfPmosLPyj08hOWilgVtCC3X4N4VGVq41uaseSOKPHYrfIWbspAn2hBarsG9qzKMgft3ZcibxDeclYU80YbQcg3uXZOhpUoGlHD84BfckIWMBO8pCWfnMoyB+9dlCBbI1LpFzhnv6LHUkXlQ92GZqKVhkPThOp11DRxz1hLuj/qiF+EPha+tnkw/v7JSUQGP4AWZC8kCn2jUWc/YzCW4jTpEzlSTqUX9q+HN7l1kfI3y+Knhb/ARNsmCAr9C+GT865/AD8q9CwbggcjG4QOZO+ca3sA7yh2mi8zxeXfnT+4tmBEZeDweT8nzB5vsgslxJqGwAAAAAElFTkSuQmCC>

[image2]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADcAAAAXCAYAAACvd9dwAAACDklEQVR4Xu2Wu0sdURDGx6AhFopFJBYBH52CVdRSSLDWLmKthWBjJTaChVb5D0IkYGVtEcWQIqCNSogiiiGiIBY2igoqPtD57pzFObN7dm9utJH9wYc738x5refcs0Q5OTnPiTHWKeuc1W9yaZSz1ll3rENWk58ucMUaZr1hVbK6WHu64CnZZH1X8QZrScVpXLPKVHzCGlAxwMKt3nsVjg5r/CfVJINZ4NVY0zDLarYmxftDPM76wur1Uz4vSf6li+S/sVL5TfHJAHiYTBqomTEe5mT7s3EmL1hrrF2SfVwq0TaxhHzNAknNX+X9Ijm/mqx+Upkj+TGos4kiCC0i5FuiOmibZPtZkMOZPmB9czF+XP6Jr6wbVqtNpBBaRMi3vCJ/gUd+ugD8ehWPOK8kJkkad9pEAqFFhHxNI0kNzlmDe4awi7JA3Q9rFsMQSeM+m0ggtIiQr0H+tfF+Or9WeRXqOaKY/j0mSBp8sIkUzih5EHhb1lRg8kntAPxR9zzl4vaHdAF4uCMzQQcoTLpzsvhIyZOE907FOFvYEZqkdgD+W/c8zbol/9qqIqn5rLwY86xj8rdAKWCgQRV/cp4m2kYtysPZwnWg6SbZDRG4si5UDHYp3n8BvIFV1g7J23wMcE9isGWSu/OS4h8IPawV44E/JG1xDUR9WNpIcvj2xN99P/0APr/swDk5OTk5EffXsY/JXAgxxgAAAABJRU5ErkJggg==>

[image3]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAF0AAAAXCAYAAABpskPJAAADIElEQVR4Xu2YS8hNURTHl/dz4Jm8pSgTeZW8CwMjRR4D8c1M9CGJyMBrQgYiSoSSEIWEEuUxIUJCGUhiICZSHslr/b+99v3WXmefc4/BPV+0f/Xv3P3f656zz7r77LP2JUokEonE/0gP1jXWb9Z9VruwuxQPrCGMZ11nTWC1Z41k7WVd0EEVcpbcfT5ndTd9RcxlfSf33aumz/OINYPVmTWEtYX1MYgQBpM7UTdp95U2ElSPe+RivWJgsDoGeh9EVEMnctceJu0O0h5Yi8hnHuuIao+i7P12FE8LP1KUz6wzxsOs/Wa8ItZRdhCeWazL5Aa9ndUz7K6MO6y3xttD+ePWxGLOsQ4Z7wXrAGsXa5DpC8AJlxhvs/hlKUr6dNY2a7YBGN9B400Vvx6I6WW886zjxrtl2lFmkjshEqNpEr+P8fMoSvo0avuk+6UEa6xmuPgLjW9BDLTKeJZSSV9L7st4yWkWiz/Z+HkUJX0K6yS5/lOsL6zbQUTjGUfu+hinpr/4G41vwcvRJ/6rHGPL5EPWD3LLKd5br8JuB9ZYnGCs8ReIv8z4eRQlHT/oa+MhFmtsVcwmd83Vxu8t/mHjx2im1sRDO8PuFux7EHGZ6mWldGAmaBaJP8f4eRQlPcY7qh8/gjWppApfWsxoctfDk63pJ/4O41susW7IZ5S7PvErahFxTpOLQ0lew6/pWAI0y8VHOVmGv036TXLxA4yvmciaX1Jj5Dt5YN+B620y/lDxi55o/4NpUF77xBexlVzMUm12EbOR1UtscChJ4XU1fiPB9fKql6Ja/RnrhDWpNfGe2H36khR7lQCY+4x3RXwNXq55M7Ne0rEL1PidXZX8Yj0x3gbKjsPe50XWU9XW2KRjR6q5K36G2KxGW5dR/vG0cZ7d5PpQDVgekysbPZhViG1SXhWgLLbjR1tPuNh9+p0mtvWalxQuG/sprI78944pLwCl3E85ItC+cAD+K1lvPMxYvBSx03sjxw+UfRzxPwfO62d45nGrCD+zsQPHWI6G3S3E7tP/VQKhFMQRFZ7FrxCf5Lgm7E4kEolEIpH41/gDDDrkp25ALQsAAAAASUVORK5CYII=>

[image4]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAgAAAAWCAYAAAD9091gAAAAZUlEQVR4XmNgGAXIwACI+4CYFcpPAuIOmCQbEB8G4hAg/g/E34FYCqoIxGfYD1WYCRWQgfJB7FsgRi1U4B5UEAY4kNhgAJI8gC6IDEAK7NEFYSCCAdV4DHCZgYCCP0A8BV1wyAAAFGsUcAMS3ucAAAAASUVORK5CYII=>

[image5]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAUcAAAAWCAYAAABT7F6NAAAAzElEQVR4Xu3ZMWoCQRSA4WkMnkFyiNwgjUcQtLbLIdJZiIUgWCqKHiSBHCFdilzDRohv3QF1ZZEUgch+H/zszCzTPhY2JQAAAAAAAAAAAID/7SmaRq28H0bj02uA5nmIPqJe9BPtok4qB2SxB2ikt/x8SeUwfMz7Yv2V13X60bamTbSOVtEyWkSz4y2AO/Can9/p8kuxfbYGaKxiML5XDwGarhiOz9XDG7rR5BeNymsA92GQ/HwBuPKZDEeAK/toXj0EAAAAAAAAgD9xAP2SIvpl4QNZAAAAAElFTkSuQmCC>

[image6]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAsAAAAWCAYAAAAW5GZjAAAAiUlEQVR4XmNgGAUDBVyBeAMQ56FLIAMTIP4PxA5QfhWUDwPTYAxdqIQQQg4MQGKroey/yILPYRwk8I8BImcOxNEgAQeogDtCDRw8YoDIwZ0DsgbZbcjgGgNEThIm0AAVwAYuMmCRAwmooondA+K1UDkQ6INJgEIB5FuY+2bAJIDgPlQsHklseAIAUe8iq34ClPEAAAAASUVORK5CYII=>

[image7]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAEcAAAAWCAYAAACSYoFNAAAA00lEQVR4Xu2VPQoCMRCF5wx2HsDSTrDdQvEIFhbewANYWVhZCDZioShairBXsbFUsPEU/rwxWQjDprARJe+DD5L3SLED2YgQQgghhKRDG+ZwYIuUacAnzPx+6PcF82CdFHVxg6iYXLO9X9/DooQu3EXcwg1cwxVcwtn71B+gQ7jZEDzEdU3YM10SZOIG0DG5chXXhdcrKfTaxD7+JK6r2qKEFpx84Ngd+21GEh/OUeJdMugAaiY7w4PvlGnQJYW+UvoaFf+XRdBdfNYPMkIIIeR7vACWwzE1cSl4cAAAAABJRU5ErkJggg==>

[image8]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACoAAAAWCAYAAAC2ew6NAAAAyElEQVR4XmNgGAWjYBSMglFAbeAKxBuAOA9dYrAAEyD+D8QOUH4VlA8D05DYAwZ0GSCOEkITB4mthrL/IktgAeFAvBgHXgTEC4B4PhDPBeI5QDwRrItEAHLQc3RBIPjHAJEzB+JoNDm6AwcGiGPc0cRB4BEDRA45CQwYAEUtLodcY4DISaJLYAEuQNxFAm6BaCMeNDDgduhFBtxyAwJAjlFFE7sHxGuhciDQhyQ3YACU20G5GpYeZyDJ3YeKxSOJjYJRMAqGKgAAtaIxNWNF+VQAAAAASUVORK5CYII=>

[image9]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAA0AAAAUCAYAAABWMrcvAAAAcklEQVR4XmNgGAUDCCSBmAldEA14oguAwH8gZkEXhIJfQMyFLggDII2saGK/gZgHTQwDIGsEaeBFksMLQBpBGvjQJfCBf1DMji6BC4AUw/wAYrMhyWEFyBqQxdADBw7+MuAOVpBGjOhQZiDsjFh0gUEIACHGEThB/P5TAAAAAElFTkSuQmCC>

[image10]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAGMAAAAWCAYAAADU1CLnAAABIElEQVR4Xu3XMUsCcRjH8UfKF1BBgzY4OPQCGgRfQtCkL0Gh0dUhkN5EuyC0uDS4NLa25CAogquLBQ1BQ/V7+DfcPdyd9787uILfB76Dz1+Xe9DzRIiI/pWWHVB5eugbzewBlWMrbiH0B1yIW0bXHnhqoj66DkQZ6DI+7TClB/SKLtE5OkOn6Cj4JkrvSbL9VOlnGnZI+RyLu7A39iDBFNXtkIqhy/D5drzbARVjgdbilnFozuLcibv5J0WeNugeHYhbxiR0Gq2CxuhqT+RBnzGWgdc+P1U7O6Ds3tCHmQ3ELaNm5lHm6MQOyZ/efOO+ATp/scMYX8LniVz0oUwvuN4jojxK/KKiPKMVaov7i1wNH1MZOmiIRuj2NyIiIirAD5kCNDn+KlGqAAAAAElFTkSuQmCC>