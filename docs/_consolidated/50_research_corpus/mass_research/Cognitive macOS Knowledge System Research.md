# **Cognitive Architecture for Local-First Personal Knowledge Systems: A Research Report on macOS System Design**

The synthesis of cognitive science and high-performance systems engineering on the macOS platform represents a new frontier in personal knowledge management (PKM). Historically, knowledge systems have functioned as passive digital filing cabinets, placing the burden of organization, retrieval, and synthesis entirely on the user. However, the advent of Apple Silicon—characterized by its unified memory architecture and specialized neural and graphical processing units—enables a shift toward "cognitive computing." This paradigm treats the software not as a tool, but as an active participant in the user's thinking process.1 By integrating a sophisticated stack consisting of Swift, Rust, Metal, and on-device machine learning (MLX), it is possible to construct a system that mirrors human cognitive patterns while maintaining absolute data sovereignty through a local-first, no-cloud architecture.

The proposed architecture leverages an existing foundation of HNSW vector search via the usearch library in Rust, a Metal-accelerated graph renderer, and an append-only OpLog that captures every text edit mutation within an NSTextView-based editor utilizing a Block Tree Kernel (BTK). This report investigates the interdisciplinary landscape required to build six advanced cognitive capabilities upon this foundation, examining the theoretical justifications, technical implementation patterns, and user experience (UX) considerations for each.

## **Capability 1: Contextual Shadows — Ambient Semantic Retrieval Panel**

Contextual Shadows represent a departure from the traditional search-and-retrieve cycle. Instead of requiring the user to pause their creative flow to query a database, the system proactively surfaces relevant information in a peripheral panel. This "ambient" approach ensures that the knowledge base remains a living extension of the user's current focus, rather than a dormant archive.1

## **Cognitive Science Justification: Calm Technology and Peripheral Awareness**

The strongest justification for Contextual Shadows lies in the theory of "Calm Technology," originally proposed by Mark Weiser and John Seely Brown at Xerox PARC and further refined by Hiroshi Ishii and the Tangible Media Group at MIT.3 Calm technology is designed to reside in the user's "attentional periphery," minimizing cognitive load by providing information that can be moved into the "attentional center" only when necessary.3

This is supported by the "cocktail party effect," which demonstrates the human capacity to selectively focus on one stream of information while remaining subconsciously aware of others.6 In a PKM context, Contextual Shadows exploit this by presenting semantically related notes as subtle "shadows" of the current task. Furthermore, the Recognition-Primed Decision (RPD) model developed by Gary Klein in the field of Naturalistic Decision Making (NDM) suggests that experts make decisions by recognizing patterns and typicalities in a situation.7 Contextual Shadows act as a digital stimulant for this recognitional process, surfacing historical cues and expectancies that help the user categorize their current work within the context of their previous insights.7

## **Competitive Analysis: Proactive Retrieval Models**

| System | Successes | Failures |
| :---- | :---- | :---- |
| **Mem.ai (Heads Up)** | Proactively surfaces related notes, meeting history, and relevant collections.1 | Cloud-dependent; introduces latency and privacy risks; retrieval can feel opaque.9 |
| **Obsidian (Backlinks/Graph)** | Local-first; high user control; strong community plugins. | Passive; requires the user to proactively check sidebars or open graph views. |
| **Reflect** | Clean UI; automated backlinking; integrated calendar support. | Limited semantic depth; retrieval is often based on literal keyword matching rather than intent. |
| **Microsoft Recall** | Comprehensive capture of all screen activity for retrospective search.10 | Privacy nightmare; lacks "calm" integration; focuses on a timeline rather than semantic relevance.12 |

Mem.ai’s "Heads Up" feature is the primary conceptual competitor, offering real-time contextual linking that eliminates the need for manual organization.1 However, its reliance on remote servers contradicts the requirement for local sovereignty. The proposed macOS system improves upon this by using Model2Vec embeddings to achieve sub-millisecond retrieval, ensuring the "shadows" update with zero perceived latency.

## **Technical Implementation Patterns: Swift \+ Rust \+ HNSW**

The implementation of Contextual Shadows requires a high-throughput pipeline between the editor and the vector index.

1. **Semantic Chunking**: As the user types in the NSTextView, the Block Tree Kernel (BTK) monitors the OpLog for "semantic boundaries" (e.g., the completion of a paragraph or a specific number of tokens).  
2. **On-Device Embedding**: The system passes the text fragment to a local Model2Vec model. Model2Vec is chosen for its efficiency, generating high-quality embeddings in approximately 1ms per paragraph.14  
3. **Rust-HNSW Retrieval**: The resulting vector is sent via FFI to the usearch HNSW index in Rust. usearch is uniquely suited for this as it is concurrent-by-design, allowing searches to occur on background threads without locking the UI or the indexing process.15  
4. **Ranking and Decay**: The system applies a custom ranking algorithm that combines cosine similarity with a temporal decay function to prioritize recent context.  
   ![][image1]  
5. **Metal Rendering**: The "Shadows Panel" is rendered using a Metal-backed SwiftUI view, utilizing low-alpha blending and Gaussian blurs to ensure the information remains visually in the periphery, adhering to the "calm" design principle.3

## **Critical UX Pitfalls**

The most significant pitfall is "Semantic Noise." If the shadows update too frequently or with irrelevant information, the user will experience "notification fatigue" and eventually disable the feature.3 To avoid this, the system must implement a "relevance threshold" and utilize "change blindness" techniques—where the panel updates only when the user is not actively typing or during natural pauses.5

## **Capability 2: Ambient Cross-App Knowledge Capture**

A native macOS knowledge system should not be a silo. Ambient Cross-App Capture allows the system to observe the user’s activity across the entire OS, indexing information from browsers, Slack, and emails without requiring manual input.

## **Cognitive Science Justification: The Extended Task Environment**

This capability is justified by the "Information Dominance" framework and the concept of the "Task Environment" in writing research.8 In the Hayes model of composing, the task environment includes all external resources and social contexts the writer interacts with.16 By capturing information from other apps, the system ensures that the user's "external memory" is as comprehensive as their "internal memory," reducing the cognitive effort required to synthesize information from multiple sources.8

## **Competitive Analysis: Privacy vs. Utility**

| System | Mechanism | Pros | Cons |
| :---- | :---- | :---- | :---- |
| **Microsoft Recall** | Screenshots every 3-5 seconds \+ OCR.10 | Comprehensive; searchable timeline.17 | "Creepy" privacy risks; unencrypted local archives (initially).10 |
| **Rewind.ai** | Screen recording \+ Audio transcription. | Powerful retrospective search. | Resource intensive; subscription-based; privacy concerns. |
| **Granola** | Focused meeting notes capture. | High utility for specific tasks. | Narrow scope; lacks deep PKM integration. |

The primary lesson from Microsoft Recall is that users are deeply sensitive to the "behavioral archive" problem.13 While Recall builds a permanent archive of cognitive activity that could be exploited for profiling, a local-first macOS system can provide similar utility while maintaining absolute privacy through local encryption and hardware-bound keys (Secure Enclave).18

## **Technical Implementation Patterns: AXUIElement \+ ScreenCaptureKit**

The system employs a multi-tiered capture strategy:

1. **Accessibility Traversal**: Using Rust FFI to interface with AXUIElement, the system polls the active window for structured text.19 This is the most efficient method, as it extracts text directly from the UI hierarchy (e.g., kAXValueAttribute or kAXDescriptionAttribute).20  
2. **ScreenCaptureKit OCR**: For apps with "sparse" accessibility trees (like some Electron apps or legacy software), the system uses ScreenCaptureKit to grab window snapshots.22 These are processed by the macOS Vision framework’s local OCR or a custom MLX model to extract text.  
3. **FTS5/GRDB Indexing**: Extracted text is stored in a local SQLite database using the FTS5 module for rapid full-text search. The GRDB wrapper in Swift provides a type-safe interface for managing these captures.  
4. **Process Attribution**: Each capture is tagged with its source app PID, window title, and a unique URL (if from a browser), allowing the user to "teleport" back to the original context.20

## **Critical UX Pitfalls**

"Privacy Theater" vs. Actual Security is the main risk. Users must be given granular control over what is captured.11 A major pitfall is the failure to handle "Sensitive Information" (passwords, banking data). The system should implement default filters using the NaturalLanguage framework to identify and redact entities like credit card numbers or Social Security numbers before indexing.18

## **Capability 3: Cognitive Friction Detection via Edit Telemetry**

By analyzing the fine-grained dynamics of how a user types and edits, the system can detect when they are struggling with a concept or when they have entered a "flow state."

## **Cognitive Science Justification: Keystroke Logging and Writing Dynamics**

Research in writing processes, particularly the use of tools like "Inputlog," demonstrates that keystroke dynamics are a window into cognitive effort.16 A key metric is the "P-burst" (pause burst), defined as a period of text production delimited by pauses exceeding a certain threshold (usually 2 seconds).26 Longer P-bursts and higher fluency indicate low cognitive friction and successful "idea-to-word" conversion.16 Conversely, frequent revisions and long inter-key intervals signal cognitive load in working memory.26

Detecting these patterns allows the system to identify "Flow States"—the "optimal experience" where challenge and skill are in balance.28 Flow is associated with "transient hypofrontality," a deactivation of the prefrontal cortex that reduces self-criticism and enhances intuitive action.28

## **Competitive Analysis: Research vs. Application**

| Tool | Focus | Strengths | Weaknesses |
| :---- | :---- | :---- | :---- |
| **Inputlog** | Academic research on writing.16 | Fine-grained millisecond tracking; multimodal integration.16 | Windows-only; research tool, not a daily productivity app. |
| **Grammarly** | Linguistic correctness and tone. | Real-time feedback. | Evaluates the *product*, not the *process*; privacy concerns. |
| **RescueTime** | Time management. | Broad app tracking. | Lacks semantic or cognitive depth. |

The gap in the market is a tool that uses research-grade keystroke logging to provide *metacognitive* feedback in a personal knowledge base.

## **Technical Implementation Patterns: OpLog \+ Rust Analysis**

1. **OpLog Instrumentation**: Every text mutation (insert, delete, replace) is logged in the append-only OpLog with a millisecond timestamp.27  
2. **Burst Analysis in Rust**: A background process in Rust analyzes the OpLog stream. It calculates:  
   * **Inter-Key Intervals (IKI)**: The time between successive keystrokes.  
   * **P-Burst Length**: The duration and word count of fluent typing segments.26  
   * **Product/Process Ratio**: The ratio of the final text length to the total number of characters produced (including those deleted).27  
3. **Flow State Estimation**: Using a sliding window, the system estimates the "Flow Index."  
   ![][image2]  
4. **Metacognitive Markers**: When the system detects a significant "Friction Spike" (long pauses and heavy revision), it can automatically tag the current paragraph with a "Refining" or "Difficult" metadata marker in the OpLog.

## **Critical UX Pitfalls**

"The Observer Effect" is the primary risk. If users know their typing is being monitored, they may become self-conscious, which ironically *increases* cognitive friction and breaks flow.28 The system must frame this as a private, supportive tool for self-reflection rather than a "performance monitor."

## **Capability 4: Temporal Knowledge Graph — Conceptual Drift and Belief Evolution**

Knowledge is not static. A Temporal Knowledge Graph (TKG) tracks how ideas and their relationships change over time, allowing users to see how their beliefs have evolved.30

## **Cognitive Science Justification: Explanatory Coherence and Semantic Drift**

Paul Thagard’s Theory of Explanatory Coherence (ECHO) suggests that our belief systems are networks of propositions where coherence is determined by explanatory relations.31 Belief revision occurs when a new proposition coheres better with the evidence than existing ones, leading to the rejection of previous beliefs.33

Furthermore, "Diachronic Word Embeddings" show that the meanings of words shift over time based on their context.34 William Hamilton’s research proposes two laws: the "Law of Conformity" (frequent words change slowly) and the "Law of Innovation" (polysemous words change quickly).35 A TKG allows the user to visualize this drift in their own thinking.

## **Competitive Analysis: Static vs. Dynamic Graphs**

| Feature | Obsidian Graph | Temporal Knowledge Graph (Proposed) |
| :---- | :---- | :---- |
| **Dimension** | Static spatial (2D/3D). | 4D (Spatial \+ Temporal).30 |
| **Relation Type** | Hard links (\[\[link\]\]). | Temporal quadruples ![][image3].36 |
| **Logic** | Manual navigation. | Anomaly detection and drift analysis.36 |
| **Embeddings** | Static vector. | Diachronic embeddings (DE).38 |

Existing PKM tools provide "Daily Notes," but they fail to show the *structural* evolution of the knowledge graph. They show *that* you wrote something on a specific day, but not *how* your definition of "Intelligence" changed between 2022 and 2024\.

## **Technical Implementation Patterns: Diachronic Embeddings \+ SQLite**

1. **Quadruple Storage**: Relations are stored as ![][image4] in the GRDB/SQLite index.36  
2. **Diachronic Entity Embedding (DE)**: The system implements a model-agnostic DE function in Rust. This function takes an entity and a timestamp to provide a time-sensitive vector.30  
   ![][image5]  
3. **Snapshot Diffing**: The system uses Orthogonal Procrustes alignment to compare vector space "snapshots" across different time slices.34 This is a numerically stable method using Singular Value Decomposition (SVD) to align the "arbitrarily rotated" spaces of different time periods.34  
4. **Orphan Knowledge Detection**: An algorithm (AnoT) summarizes the TKG into a "rule graph" to identify anomalies or "orphan" nodes that have lost their semantic connection to the evolving graph.36

## **Critical UX Pitfalls**

"Temporal Overload" occurs when the user is overwhelmed by the sheer amount of historical data. The UI must utilize "time-slicing" and "semantic trajectories" to help the user navigate the timeline without getting lost in the "spaghetti" of a growing graph.41

## **Capability 5: Night Brain — Autonomous Background Processing**

While the user sleeps, the system should perform the heavy lifting of synthesis, summarization, and graph maintenance, ensuring the knowledge system is "primed" for the next day's work.

## **Cognitive Science Justification: Memory Consolidation and Ambient Analytics**

This is modeled on the biological process of sleep, where the brain consolidates memories and finds novel connections.3 Ambient analytics suggests that sensemaking is a slow, subliminal process that benefits from the "multisensory perception of intentional environmental cues".3 By processing the day's notes and cross-app captures in the background, the system builds the "intuition" that makes the "Contextual Shadows" effective.

## **Competitive Analysis: Background OS Tasks**

The primary competitive example is **Apple Photos**, which performs intensive ML tasks (face recognition, object detection) only when the Mac is plugged in and idle.43 This provides a blueprint for non-intrusive background processing.

## **Technical Implementation Patterns: NSBackgroundActivityScheduler \+ MLX**

1. **Deferrable Scheduling**: Using NSBackgroundActivityScheduler, the system schedules synthesis tasks for "off-peak" hours.43  
2. **Thermal-Aware Throttling**: The synthesis engine monitors the ProcessInfo.thermalState. If the state moves from nominal to fair or serious, it uses shouldDefer to gracefully pause and save its state.45  
3. **MLX Inference**: On-device LLMs (via MLX) perform tasks such as:  
   * **Analogy Mining**: Finding hidden links between disparate notes (based on ECHO principles).32  
   * **Summarization**: Creating "Executive Summaries" of the day’s activities.  
   * **Rule Discovery**: Updating the TKG’s rule graph.36  
4. **Incremental HNSW Updates**: The usearch index is updated with new vectors in parallel, leveraging Rust’s thread safety.15

## **Critical UX Pitfalls**

The "Black Box" problem. If the system changes the knowledge graph or summarizes notes without the user seeing *why*, it can feel like a loss of agency. The system must provide a "Morning Briefing" or a "Maintenance Log" that transparently shows the synthesized connections made overnight.

## **Capability 6: Spatial Graph Interaction — Physics-Driven Thinking Canvas**

The final capability provides a physical, interactive environment where nodes in the knowledge graph are treated as objects with mass, charge, and friction, allowing for "tactile" thinking.

## **Cognitive Science Justification: Tangible Media and Situated Interaction**

The justification is found in "Tangible Media" and "Situated Interaction," which exploit the human senses of touch and kinesthesia.5 By giving information a physical embodiment, the system turns perception into an active task.6 This alignment of physicality and control allows the user to manipulate concepts in a way that feels natural and intuitive.

## **Competitive Analysis: Infinite Canvases**

| System | Approach | Successes | Failures |
| :---- | :---- | :---- | :---- |
| **Muse** | Spatial canvas for research. | Excellent UX for visual grouping. | Lacks semantic intelligence; purely manual. |
| **Heptabase** | Card-based knowledge graph. | Strong visual structure. | Graph physics are basic; no temporal dimension. |
| **Obsidian Graph** | Force-directed graph. | Good for seeing "clusters." | Performance drops significantly after \~2,000 nodes.47 |

The proposed system uses the Barnes-Hut algorithm to ensure ![][image6] performance, allowing for smooth interaction with graphs containing tens of thousands of nodes.48

## **Technical Implementation Patterns: Metal \+ Barnes-Hut \+ Rust**

1. **Barnes-Hut Physics in Rust**: Instead of a naive ![][image7] approach, the system uses a Quadtree (2D) to group distant nodes, treating them as a single point of mass.48 The barnes\_hut library in Rust provides the foundation for this.50  
2. **Metal GPU Kernels**: The force calculations are offloaded to Metal. This involves four main kernels:  
   * **Reset**: Clearing node states.  
   * **Bounding Box**: Computing the canvas limits.  
   * **Construction**: Building the tree hierarchy (using dynamic parallelism on the GPU).49  
   * **Force**: Calculating attraction and repulsion forces via parallel tree traversal.49  
3. **Haptic Feedback**: Integrating with the macOS NSHapticFeedbackManager, the system provides "tactile clicks" when nodes are merged or when a strong semantic bond is formed.  
4. **Spatial persistence**: Node positions are saved in the GRDB index, allowing the user to curate their "thinking landscape" over time.

## **Critical UX Pitfalls**

"The Elastic Mess." Without careful tuning of the physics parameters (gravity, spring constant, friction), the graph can become jittery or "explode".51 The system must implement a "Layout Lock" and allow users to "pin" certain key nodes to the canvas to provide stability.

## **Conclusion: The Integrated Cognitive Loop**

Building a cognitive computing system on macOS is an exercise in balancing high-performance engineering with nuanced psychological insights. By strictly adhering to a local-first architecture, the system avoids the "creepy" surveillance pitfalls of cloud-based AI while providing a level of responsiveness that feels like a natural extension of the user's mind. The combination of Contextual Shadows for peripheral awareness, Ambient Capture for an extended task environment, and Physics-Driven Interaction for tangible thinking creates a powerful "cognitive loop" that empowers the user to turn fragmented information into deep, synthesized knowledge.

#### **Works cited**

1. What Is Mem AI? The AI Note-Taking App That Organizes for You | Lovable, accessed March 26, 2026, [https://lovable.dev/guides/what-is-mem-ai](https://lovable.dev/guides/what-is-mem-ai)  
2. Introducing Mem 2.0: The World's First AI Thought Partner, accessed March 26, 2026, [https://get.mem.ai/blog/introducing-mem-2-0](https://get.mem.ai/blog/introducing-mem-2-0)  
3. Ambient Analytics: Calm Technology for Immersive Visualization and Sensemaking, accessed March 26, 2026, [https://www.visus.uni-stuttgart.de/pumaApi/v1/locales/en/pages/8e94fee7-4639-11e9-8dd0-000e0c3db68b/contentElements/8a54995a-d37e-11e8-8d6c-000e0c3db68b/publications/8e5d7ac8e4b36e3832c9f4d297960ad0/documents/hubenschmid2026ambient.pdf](https://www.visus.uni-stuttgart.de/pumaApi/v1/locales/en/pages/8e94fee7-4639-11e9-8dd0-000e0c3db68b/contentElements/8a54995a-d37e-11e8-8d6c-000e0c3db68b/publications/8e5d7ac8e4b36e3832c9f4d297960ad0/documents/hubenschmid2026ambient.pdf)  
4. Principles and Patterns for Non-Intrusive Design \- Calm Technology, accessed March 26, 2026, [https://calmtech.com/book](https://calmtech.com/book)  
5. ambient displays, accessed March 26, 2026, [https://www.lri.fr/\~anab/teaching/M2R-TUI/4-Tangibles-Ambient.pdf](https://www.lri.fr/~anab/teaching/M2R-TUI/4-Tangibles-Ambient.pdf)  
6. Ambient Displays: Turning Architectural Space into an Interface between People and Digital Information \- ResearchGate, accessed March 26, 2026, [https://www.researchgate.net/publication/220696504\_Ambient\_Displays\_Turning\_Architectural\_Space\_into\_an\_Interface\_between\_People\_and\_Digital\_Information](https://www.researchgate.net/publication/220696504_Ambient_Displays_Turning_Architectural_Space_into_an_Interface_between_People_and_Digital_Information)  
7. (PDF) In Naturalistic Decision Making \- ResearchGate, accessed March 26, 2026, [https://www.researchgate.net/publication/270960095\_In\_Naturalistic\_Decision\_Making](https://www.researchgate.net/publication/270960095_In_Naturalistic_Decision_Making)  
8. Implications of the Naturalistic Decision Making Framework for Information Dominance. \- DTIC, accessed March 26, 2026, [https://apps.dtic.mil/sti/tr/pdf/ADA341758.pdf](https://apps.dtic.mil/sti/tr/pdf/ADA341758.pdf)  
9. Switch from Notion to Mem \- Mem – Your AI Thought Partner, accessed March 26, 2026, [https://get.mem.ai/compare/notion-vs-mem](https://get.mem.ai/compare/notion-vs-mem)  
10. Microsoft's New 'Recall' Feature Is Equal Parts Cool and Dangerous \- Lifehacker, accessed March 26, 2026, [https://lifehacker.com/tech/microsofts-new-recall-feature-is-equal-parts-cool-and-dangerous](https://lifehacker.com/tech/microsofts-new-recall-feature-is-equal-parts-cool-and-dangerous)  
11. Retrace your steps with Recall \- Microsoft Support, accessed March 26, 2026, [https://support.microsoft.com/en-us/windows/retrace-your-steps-with-recall-aa03f8a0-a78b-4b3e-b0a1-2eb8ac48701c](https://support.microsoft.com/en-us/windows/retrace-your-steps-with-recall-aa03f8a0-a78b-4b3e-b0a1-2eb8ac48701c)  
12. Is Microsoft Recall not just Apple Time Machine?? : r/MacOS \- Reddit, accessed March 26, 2026, [https://www.reddit.com/r/MacOS/comments/1db86yw/is\_microsoft\_recall\_not\_just\_apple\_time\_machine/](https://www.reddit.com/r/MacOS/comments/1db86yw/is_microsoft_recall_not_just_apple_time_machine/)  
13. Microsoft Recall Is Coming to Windows 11: Everything You Need to Know About AI Screenshots \- Cambridge Analytica, accessed March 26, 2026, [https://cambridgeanalytica.org/news/microsoft-recall-is-coming-to-windows-11-everything-you-need-to-know-about-ai-screenshots-50483/](https://cambridgeanalytica.org/news/microsoft-recall-is-coming-to-windows-11-everything-you-need-to-know-about-ai-screenshots-50483/)  
14. Tips for Implementing AI in Your Note-Taking Routine \- Mem, accessed March 26, 2026, [https://get.mem.ai/blog/tips-for-implementing-ai-in-your-note-taking-routine](https://get.mem.ai/blog/tips-for-implementing-ai-in-your-note-taking-routine)  
15. unum-cloud/USearch: Fast Open-Source Search ... \- GitHub, accessed March 26, 2026, [https://github.com/unum-cloud/usearch](https://github.com/unum-cloud/usearch)  
16. 二语写作 \- Inputlog, accessed March 26, 2026, [https://www.inputlog.net/wp-content/uploads/2020\_CJSLW-Designing\_KSL-studies.pdf](https://www.inputlog.net/wp-content/uploads/2020_CJSLW-Designing_KSL-studies.pdf)  
17. Manage Recall for Windows clients | Microsoft Learn, accessed March 26, 2026, [https://learn.microsoft.com/en-us/windows/client-management/manage-recall](https://learn.microsoft.com/en-us/windows/client-management/manage-recall)  
18. Update on Recall security and privacy architecture | Windows Experience Blog, accessed March 26, 2026, [https://blogs.windows.com/windowsexperience/2024/09/27/update-on-recall-security-and-privacy-architecture/](https://blogs.windows.com/windowsexperience/2024/09/27/update-on-recall-security-and-privacy-architecture/)  
19. SwiftUI/MacOS: Contents Scrapping With AccessibilityAPI | by Itsuki | Feb, 2026 \- Medium, accessed March 26, 2026, [https://medium.com/@itsuki.enjoy/swiftui-macos-contents-scrapping-with-accessibilityapi-c7e39daf2b19](https://medium.com/@itsuki.enjoy/swiftui-macos-contents-scrapping-with-accessibilityapi-c7e39daf2b19)  
20. AXUIElementPerformAction(\_:\_:) | Apple Developer Documentation, accessed March 26, 2026, [https://developer.apple.com/documentation/applicationservices/1462091-axuielementperformaction](https://developer.apple.com/documentation/applicationservices/1462091-axuielementperformaction)  
21. Screen2AX: Vision-Based Approach for Automatic macOS Accessibility Generation \- arXiv, accessed March 26, 2026, [https://arxiv.org/html/2507.16704v1](https://arxiv.org/html/2507.16704v1)  
22. enable Accessibility Tree on macOS in the new Teams (work or school), accessed March 26, 2026, [https://techcommunity.microsoft.com/discussions/teamsdeveloper/enable-accessibility-tree-on-macos-in-the-new-teams-work-or-school/4033014](https://techcommunity.microsoft.com/discussions/teamsdeveloper/enable-accessibility-tree-on-macos-in-the-new-teams-work-or-school/4033014)  
23. enable Accessibility Tree on macOS in the new Teams (work or school), accessed March 26, 2026, [https://techcommunity.microsoft.com/t5/teams-developer/enable-accessibility-tree-on-macos-in-the-new-teams-work-or/m-p/4236470](https://techcommunity.microsoft.com/t5/teams-developer/enable-accessibility-tree-on-macos-in-the-new-teams-work-or/m-p/4236470)  
24. Recall overview \- Windows apps \- Microsoft Learn, accessed March 26, 2026, [https://learn.microsoft.com/en-us/windows/apps/develop/windows-integration/recall/](https://learn.microsoft.com/en-us/windows/apps/develop/windows-integration/recall/)  
25. Using Keystroke Logging in Writing Research, accessed March 26, 2026, [https://attw.org/using-keystroke-logging-in-writing-research/](https://attw.org/using-keystroke-logging-in-writing-research/)  
26. Making sense of L2 written argumentation with keystroke logging | Journal of Writing Research, accessed March 26, 2026, [https://www.jowr.org/jowr/article/download/920/934/2467](https://www.jowr.org/jowr/article/download/920/934/2467)  
27. (PDF) Keystroke Logging in Writing Research \- ResearchGate, accessed March 26, 2026, [https://www.researchgate.net/publication/243971626\_Keystroke\_Logging\_in\_Writing\_Research](https://www.researchgate.net/publication/243971626_Keystroke_Logging_in_Writing_Research)  
28. Flow State in Learning: Csikszentmihalyi's Theory, accessed March 26, 2026, [https://www.structural-learning.com/post/flow-state](https://www.structural-learning.com/post/flow-state)  
29. A Scoping Review of Flow Research \- PMC, accessed March 26, 2026, [https://pmc.ncbi.nlm.nih.gov/articles/PMC9022035/](https://pmc.ncbi.nlm.nih.gov/articles/PMC9022035/)  
30. Diachronic Embedding for Temporal Knowledge Graph Completion, accessed March 26, 2026, [https://cdn.aaai.org/ojs/5815/5815-13-9040-1-10-20200513.pdf](https://cdn.aaai.org/ojs/5815/5815-13-9040-1-10-20200513.pdf)  
31. Explanatory coherence \- Ideas and actions | Arts, accessed March 26, 2026, [https://watarts.uwaterloo.ca/\~pthagard/Articles/1989.explanatory.pdf](https://watarts.uwaterloo.ca/~pthagard/Articles/1989.explanatory.pdf)  
32. Explanatory coherence \- Gwern.net, accessed March 26, 2026, [https://gwern.net/doc/philosophy/epistemology/1989-thagard.pdf](https://gwern.net/doc/philosophy/epistemology/1989-thagard.pdf)  
33. 415 Paul Thagard The Cognitive Science of Science: Explanation, Discovery, and Conceptual Change. Cambridge, MA, accessed March 26, 2026, [https://journals.uvic.ca/index.php/pir/article/view/12675/3861](https://journals.uvic.ca/index.php/pir/article/view/12675/3861)  
34. Diachronic Word Embeddings \- Emergent Mind, accessed March 26, 2026, [https://www.emergentmind.com/topics/diachronic-word-embeddings](https://www.emergentmind.com/topics/diachronic-word-embeddings)  
35. Diachronic Word Embeddings Reveal Statistical Laws of Semantic Change \- Stanford Computer Science, accessed March 26, 2026, [https://cs.stanford.edu/people/jure/pubs/diachronic-acl16.pdf](https://cs.stanford.edu/people/jure/pubs/diachronic-acl16.pdf)  
36. Online Detection of Anomalies in Temporal Knowledge Graphs with Interpretability \- arXiv.org, accessed March 26, 2026, [https://arxiv.org/pdf/2408.00872](https://arxiv.org/pdf/2408.00872)  
37. A Survey on Temporal Knowledge Graph: Representation Learning and Applications \- arXiv, accessed March 26, 2026, [https://arxiv.org/html/2403.04782v1](https://arxiv.org/html/2403.04782v1)  
38. Diachronic Embedding for Temporal Knowledge Graph Completion, accessed March 26, 2026, [https://grlearning.github.io/papers/41.pdf](https://grlearning.github.io/papers/41.pdf)  
39. Diachronic embeddings for temporal knowledge graph completion \- Research Blog | RBC Borealis, accessed March 26, 2026, [https://rbcborealis.com/research-blogs/diachronic-embeddings-temporal-knowledge-graph-completion/](https://rbcborealis.com/research-blogs/diachronic-embeddings-temporal-knowledge-graph-completion/)  
40. Leveraging Knowledge Graphs for Orphan Entity Allocation in Resume Processing \- arXiv, accessed March 26, 2026, [https://arxiv.org/pdf/2310.14093](https://arxiv.org/pdf/2310.14093)  
41. A Taxonomy and Survey of Dynamic Graph Visualization | Request PDF \- ResearchGate, accessed March 26, 2026, [https://www.researchgate.net/publication/291951473\_A\_Taxonomy\_and\_Survey\_of\_Dynamic\_Graph\_Visualization](https://www.researchgate.net/publication/291951473_A_Taxonomy_and_Survey_of_Dynamic_Graph_Visualization)  
42. Visualization of a dynamic network. When \= 7, each snapshot is composed... \- ResearchGate, accessed March 26, 2026, [https://www.researchgate.net/figure/sualization-of-a-dynamic-network-When-7-each-snapshot-is-composed-of-7-consecutive\_fig1\_362271316](https://www.researchgate.net/figure/sualization-of-a-dynamic-network-When-7-each-snapshot-is-composed-of-7-consecutive_fig1_362271316)  
43. NSBackgroundActivityScheduler | Apple Developer Documentation, accessed March 26, 2026, [https://developer.apple.com/documentation/foundation/nsbackgroundactivityscheduler](https://developer.apple.com/documentation/foundation/nsbackgroundactivityscheduler)  
44. Energy Efficiency Guide for Mac Apps: Schedule Background Activity, accessed March 26, 2026, [https://developer.apple.com/library/archive/documentation/Performance/Conceptual/power\_efficiency\_guidelines\_osx/SchedulingBackgroundActivity.html](https://developer.apple.com/library/archive/documentation/Performance/Conceptual/power_efficiency_guidelines_osx/SchedulingBackgroundActivity.html)  
45. NSProcessInfoThermalStateFair | Apple Developer Documentation, accessed March 26, 2026, [https://developer.apple.com/documentation/foundation/processinfo/thermalstate-swift.enum/fair?language=objc](https://developer.apple.com/documentation/foundation/processinfo/thermalstate-swift.enum/fair?language=objc)  
46. ProcessInfo.ThermalState | Apple Developer Documentation, accessed March 26, 2026, [https://developer.apple.com/documentation/foundation/processinfo/thermalstate-swift.enum](https://developer.apple.com/documentation/foundation/processinfo/thermalstate-swift.enum)  
47. Barnes-Hut Simulation | Liam Bessell, accessed March 26, 2026, [https://people.engr.tamu.edu/sueda/courses/CSCE489/2020F/projects/Liam\_Bessell/index.html](https://people.engr.tamu.edu/sueda/courses/CSCE489/2020F/projects/Liam_Bessell/index.html)  
48. Barnes–Hut simulation \- Wikipedia, accessed March 26, 2026, [https://en.wikipedia.org/wiki/Barnes%E2%80%93Hut\_simulation](https://en.wikipedia.org/wiki/Barnes%E2%80%93Hut_simulation)  
49. Optimizing N-Body Simulation with Barnes-Hut Algorithm and CUDA | Medium, accessed March 26, 2026, [https://medium.com/@hsinhungw/optimizing-n-body-simulation-with-barnes-hut-algorithm-and-cuda-c76e78228c28](https://medium.com/@hsinhungw/optimizing-n-body-simulation-with-barnes-hut-algorithm-and-cuda-c76e78228c28)  
50. David-OConnor/barnes\_hut: A Barnes Hut n-body algorithm \- GitHub, accessed March 26, 2026, [https://github.com/David-OConnor/barnes\_hut](https://github.com/David-OConnor/barnes_hut)  
51. \[OC\] 2D N-body simulation à la Barnes-Hut (100 000 particles) \- Reddit, accessed March 26, 2026, [https://www.reddit.com/r/Simulated/comments/1ogvooc/oc\_2d\_nbody\_simulation\_%C3%A0\_la\_barneshut\_100\_000/](https://www.reddit.com/r/Simulated/comments/1ogvooc/oc_2d_nbody_simulation_%C3%A0_la_barneshut_100_000/)

[image1]: <data:image/png;base64,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>

[image2]: <data:image/png;base64,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>

[image3]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAEIAAAAWCAYAAAB0S0oJAAACaklEQVR4Xu2XP2gUQRjFP///iSJBC0UEEVKICCkEJSLEQlGxEDs1ECwMaVQwKILEQhTBwsLCIiKCoJWFtmIhiAhWFiKKoCkkRFKkMBLEv9/zm8nNvduZm93r7vKDR3bem9mbmd2dmYjMM08O+9noRIZVF9nsNDapJtjsRP6qlrPZxmC8N9jsU/1gs41ZIDYRvRz8lM5aG86KTUQDMFewSexUjamGOMjgnNhC7LmpGgjKZdmseqi6pVpYHyXBjnhI9VVszIdd+T+rnZnineq2u8Y68ivImoGJ26d6q5pRfRd7NZ+q7gb1clii+qO65sprxfreM1cjDR7IebE2r135pA/3uiAGfjzMX1K5Gb6ufwpgt7s+7sq5oM1l8qbFJicXvz5s5wAzkhrYDrH8k9irVJZB9xf3eBH4q4LrHGaluJ9fpNiPcVoi9dHRwiAAM446Xovq4yzQrp/NEqD9Kzal1qdcpiRSf5dEAgdeJbBYdUWs7qNanMUxSf9GM7aJtT/CgZj/gM0EqP+YTdAt8U6+kcYM5aPkXRCbqBjvpfE+zHqpfUbMSrH2G8nHG8L3PSg2cUX49QGfO8DYr9ZiC5eGhgP+9aC81XkhZ5z3jfwQ5M/ZJFAHin122KnuB+UTYvXXBJ4fKPfR0yX1WcMii3CETYdf7VOD+SzpLRVtt7BJXBLbpue2swLwO74v9yjzPFGNsxnwTKz9JAcArzb2+FaIPYUy4HCDg1ur4IxQGQwk9Z2nWKa6w2YFPrBRkZYeygHVRzYz+c1GBfaoRtmsAE6s69gsC/4tPcVmBmUPR0VsYKMiucftpgyy0e78A22/ie+owsGsAAAAAElFTkSuQmCC>

[image4]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAATwAAAAYCAYAAABnT0GSAAALVklEQVR4Xu2bB5BlRRWGjxFzzmlnBSmzFlpinlUQs5YYsEphVwpzjpgX0RIDJjCXursYUIylZagSZc1ZzJaKIlpmxZxjf9v9+847r+979868fTPL9lfVNbf/0/1u6nD69B2zRqPRaDQajcbewSFRaDQajXXEchRWykNSenIUdwMbUzp3FPdSrpbSJaK4l3L5lK4SxUYjcEJKm6M4lKum9NMozpmzUvpvSfsEWxenp3TJKJ4DeH9K/7b8LOY2YwW2pXR4FNchx9roWWwNti5endKDo7gH8OGUDohiYzC/TelaURwCje0CUdwNvNHyufrwUMtlrxANc+IvKX0+igvkSOv/LLqg/p2imDiXZdvzomGdsq/l671gNHRA2ROjOCfwIFbzXqh70Sgmrm/ZdodoWEes9t4XBU7Qiq/z5in9PYq7CS5yUeeaBdfymCguEHm8K+V6luufE8IDQybC3Q3XcXYUe/JIWz/3sRJWc++L5j8p3TOKffinLSZ2BzzQZ0VxDbiBrf1gwfk/E8UBvNv27M7l4T7+FsU1YjUT4W9sz34nq7n3RXO8rdB54iZnLSUOTOm1KT0oGhLPTOmFUUxcKeS1bGHpTJ1tlpdeNV6e0lFRDNzZcqdfjgbHlpROSenQkr+l5SUgsRSu5a4lPwS8EQZM4B5PTunKI/MY97N8fpYzEc7ftSu+lNJLU7pL0IElEdesQYLncCtnv67lZzttML+R5euKkw+x1bdbft+C97DD8gbLaug6J3Avx6R0m5TeZXkDo8ajU3qxTb+366T0Zsvvvou7Wz7PA0qesAnPlDzXco+S78sdbfROvmz5nVzb2Q9K6RUuL2iXdFxBe6Iv6brgvJaf2atSupDTIxe3XJey5w82UevHfe/9PCk9xfI7qHHDlF6T0oVLnmX9M1J6nI338yeltN3qfebZNn5tjBP0N84duaKtYHLhomZV+lZKryzHDFb/crZfpHR1y0HnjztdMaTLOu2kov3OcsfSksw/jPNZjq0B5T7lbOLpluvROYA41ctG5l0cbbnMNUr+cym9yPLDf0KxMRuTJ/UFbxio/0HLg9JFSt6jJZoGxp2WG5LYYpN1xFkpfaEcH5bSX228LNdLo0F7S8kfXGzPt9z5nlPsEQYSdAZiUFyJ5w56t2g3S+kMyx2OToG2sdiHMOuctB/yJAYr2hjH3IeHwZ3NNb2/iNrTw0uesgS3PfwmZdR2GIS+ZHnie3xK3y/2oe2CsgwG1KXTkr9msX0spf1S+qSNeyTcK++JAZx677U86ANti/d+75ROLRoTXe2+GfzpMx+wPNAxONTKdfXjPvd+XEr/KMcMaBz7c/AuP5HS3YrOM9hebFuLxgTwHcvXx8CO5nflicnSFvhtVj7cP+fi2VG2ttFZu8+p8OKnVeJGvJ0BSHku7mHlGG1nOQYeYPxd8howvPYel/d21ujxNzTY+Rn+0il92uWZFShDRwXNBN4LJU+8ZQjMrsyyQP0vluM4INFY43UTa3iuy59pk2Xgazapk/9j0GqTBfyo/P26Tf6OBubloKP90LKXqEEZLe7ao/H8hzDrnLCt5PW+4AdFEzts1DleEmygDnSvoPtytyt576mS1+Si/K9dfgi1+B3vB28TGGA0aMCfy9/tlutxfYJBCI225EG7cUX7akXzTOvHouvemaiw+U1NJglfn0EdthQdL1PIqVLbFGhMXj4PtX5P/rNBA/RBk7Dc2C54uNhpgHF5tan81Y6Jd1F/XzQPeWaKqP3c5f1Lx/YGl5f2zXLMS8T9rZ2H5YpngzvuGixmgWdCp6TDUL+2vNDsquULMxSDBIOihzLMiB55QvFzCzS8B887i+7hfpbKMTYGBg9arAPSmZ3hPiXv4bfRWJYOYdY5dRwnwuhBPNUdRxvETnLbko+D2y9dHmJnocyjgtaXX9nkdS3ZaCDHxlJa6J7Q/UAIWg15Diiab7daSYj9LXtqfnKFaf1YdN07+s8q2p9cnqUr4MHF6z6yoqmf4OUKefTofHbkQYttBNAH7XpvtsmLiagxKcX19EeL7iHPckvIy2LGF+pEcTkKDCbYlpxGXASNzs4L5UNpvDuPlnrTvt17h01e7xCIgXTVx4vExgvDrd9i9YGRMgcF7RtF92womvd+AI0leQ0tKzwMvGhxwgF03rFg6RPra7k2hL7n5Dh+PoPWdT707RUND0JhCx8/g5tYLoPn1AWxT8oMnQgFdYkp19CytQZ6HKDQ4iSJFxV/Q8/pBMvvaNOYdZxp/bjr3vGY0ftMwoDuV1vAe4nXjQcYNVCbiZ+iob0paIA+7Z1OcFOrn1joAdDhjrVclgHDg+ZdapabaH70rnliTyya4myeWgxKS9VpKA4xDexnR3EA1I+NUdQG/8gRVi+DFnU83KgBWtduGt5CnA2Ja1En/lcHcS70BzqNfFw+oOG1D6HvOWMZ2hraDqcJTYSEU4QmTr88irze6s/Rs5qJUNdA4L4GNsIVkZojAGgMClF7X0WL4Y4as/px171/yCZ1rXBYYUXQo8eFxmAdtdqEzcAfz3dU0VhhRbr0TqZ9wPcVm7SRP7Si+RngsUWDR1h+qbd2miAf1/WitmxhhzVq4v7l77SGLY8Ku+8cBJMFu9Vdu1CC+rExCsUYa+j8flD+SfkLaHGgQtPnGqqj2VhxTJZvB5djwKbvk7QBtKnoETaGvHcHlLt9RTukHPvAO43NhyE8m6zfOWOZt1U0UZsIwd+zR9d8uNXrgdoOdj+ox/JMuF3Qzn15BpXLlGP+YpPXQr8SrATiefYtmo+ZaZIgHgbE0ACNeG0ET0n06cdd987XErEunpY0xSfhvk73oC1XNLVZ7zzQ/uNvsCHq25yHsnH1MxMqsbsTQffLEf6VI14MoClmpplO5bhY4euyhKn9lsC2LYqWdWICHmJ66qAawP1nNrjuXMdSyWPfrxzHB6lrZwlUQ43XN8YI9uiB4FEulTwNSwFrP8sR0/HPhF078iyTuAdt7mhpL/xOJPclGxtHF3O2+Ox4t2h+GcOgEd+L4j9wtI0vF/W8uuhzTvLazWZjgvzGkXmM2kQIP7a8u+1hx9rHcqmnnVPBe1Hbwa5lE/V8Wd4BdnZCayiUAbTB051NHgrEJS96/P7wpKJ7/ETKJ1VajhJzi2VxDHybwD6rH3fdu5aYggmEvDRvq22U8e6j5h2Xp9moL4L/bcAe6wvCWV22qVCJzlGDz050ETvHTf9HO2Qk7XjhWZD37iaNWOXi7pMH954yfsta4NXQQPQ7Hxk37+IWlm2KWcQA6PFF53fi7MCsh9dVW07BYTb7IfM9lI+X+FgmXK7olPEdH5gxZdtgeblPPga1v1d07y0IOjE2OoOHJQjLH13XMWPWDLvQtaWrAvLcv4dn+23rHqD6nBOYkLCzM1xbKgnKvC6KBdqezvNdG/dygHbKTqnKnDJu3tXJZTsw2C5l9U0Jj+xxUAOddznoaHFn+Qwb3zkW8n7ioM0kpOtmoGNAiczqx9PunZWJbIQpQO2b5yK4xxNdHnhXtfAREz319VUAqN/LwyURr++C5a8ch0EQ6Pc7LmsNMzM3u1awbKARNfrxAps+SM0Lfd4QA9qLpDYZNOYD7WhIv2cC4IuLFcGJorezSP5goy/OuRY8mLWiy7tr1Ine5zxh80QxHpaJQzrEvNnfRh9PN+aPvPw+xKX2YNhZWatBZsnyxbNrd5pNxjQWCXGBU6PY6IQYy3IU5wjtguWpNh0IF6wVcXOnMT+0LD/TJj+BqcF3gbWQ1yBwKf3nCYuEAfetNgperxX7RKExFR9w3h3w+ydb/uZyrYnx1sZ8oM/R//nagP/h9XG9Glut36DYi81RaDQajXVE3DhrNBqNRqPRaOyV/A8JiXSt+TqY1gAAAABJRU5ErkJggg==>

[image5]: <data:image/png;base64,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>

[image6]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAFUAAAAYCAYAAACLM7HoAAADnElEQVR4Xu2YWchNURTHlzGUWYiQBynKiwfDy5chlCezIl+U6YkSKa+G8oLI8OLRPDyIJw+k8CAZHpSpzEKhjBnX/+69bvv+7zrnfr7v6n4+91ere/Z/rXPOPuvsvfY+V6ROnf+VaSy0MTqq9WHxTximtl9tj1oP8nmsUtvIYjPpoDaSxVbCO7XuLFZip9ovtSWxPVTtldqXYkQ5Q9Ses9hM0GncH9ZaaXLf2ksIvsiOyHe1nyxGcF4XFlsAXmiTO14DtqpdY9EDD/GQxYTJEmKmkD5R7StpLWW+tO6kAvSvHYspT6XyQ9hIPk76N6leLTVmS+X+1JofaptZNBokPMAF0pneEuJQ81KgdSXNOCwhQQZG4BG18YnmMUuyk7pe7YWEBbQT+Qxc/5DamtjGPVG6ehYjSjmgtjxpz1A7pjYv0Rgs4iiJLhhpTamJiyXE3Ug0rIJZD483CeCfI+Fl9JLwAqAtjH4PL6mDojY8tm3mLCpGBD6pnYzH2JEgBsn/qLbCghIeSZjGiNsioZSNSDQkzwNlj/tYBI5MZ8JdCXHoqDEpagwStysew89vFNp50lK8pKK9j7RRUUeCAaajd17eonIz/np5QBuDzmOglMcX6C/+xTy8uKWOBsZI2GsOkODvVuouaOtIS+GkTo9tb/pCx/QFqPfcH7Q/k2bgeugjQNzUxGfaGdJS+F4F8OB5NzXmSojj7VZj1LPYK+X+CVHLWzk5qQdj26uhaf/7xjZ+gZWImbGdhbfbQDmENpr0FD6nCByZzkhWDBYETzfg4+nzMup5cFLXxrbV0xToD5L2m6i9jb8LEl8Wd6S8TyccLcVmoct7yXEqjyX4vVFiO4Is4NvmaNg827EHEpH6bNHgkmH3x6IBsMBkLSx54BpXHO1yPMYix1QaUAXnLRaV11I+0hic25lFpZ8EH2+3oGFaolOryWdARxzKk4GXww+Bz+f7pCHmutoltXNquyV8RueBc/BxwxpKFeruUfIBXJf7U4ZNm6sSahSOx5VE+CCORxDg0WbclqDvYEcEo+KZ2hMJpeJ04hsrYcuD82ErEx/Av0i2RWRDoj1sq8ackqDzOmLgPjwLq8YGtQ8s1ggkoYFFZbD4iWsJ1b5eGbgBRkmtQT/wgeFRzSRsEr9cVhV81t1jsQbY1i/9ykLtxlTFp2q1qOYLymW7lH4/15JlEr7dz0oYVdUE/zt4HyF/jUYW2hjYyVTaSdSp8w/wG5GJ+yTtesLLAAAAAElFTkSuQmCC>

[image7]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADIAAAAYCAYAAAC4CK7hAAACXElEQVR4Xu2WzUsVURjG31JDEzVBamVBf0Arw9RFaBCuLSoiuhYEuXEjiLpw5wdtKgipRYtsoSD1F7TIRSBI0MemD3AREVEuDAyV0nwfzxk995kzc+cOd7DF/cHDnfm958ydOTPnzIiUyYRFzT/NKy7sB+dZJGTZ2Z7W/HH2wRXaL4oTmoeaB5p6qvm4rRlimRDciUm7fcDuu5zUvCVXkHtiDnTd7h/X/NCs77YI06z5xjIlpyV8IeC+5hFLHwfFHGCeC5a/mi2WFvSrZpkSPFZXWVp8FxgCjZZYOnSJaXOOfLtmg1xaHkv8fHgqBR6xr1L4aoM7NkceI5h2brjc1Jyx2x1uwaFBYs7zrJjiS/JMo5h2K+ThasgFzGh6nP1LmlnZO+GAFjGTvVdzS/Mxr5oP/s+7+GBEkzzj18S0e+O4Out8bNpf1C+IGYAjYi4azn2EsM+JArVhlqBQx4BPYtphmQ3otI7ByWKVAahjoXCBe0EuKej7hOVRW/CdDONrd8PjwClNheaYmPrh/PKOGyCXlDXNAkv8GQ6KYhwXxbTjpTlnfRRTEq63WYcXXxp+a16zBL6RZqLaYNL6fABq/Lnx3fq0oO9zluCXxB/4i5h6FRdkbyWLArUJjxt3tosFfUZYBqD4jqXyU8IjyqDvIZZKk5gaL81weCfhbvZRLQnojwGMBF+gaISJhDmD7da8Fn7QzjdxL4t/xN+L8Xe5kIBa8R+zJAxqVllmBL7Gn7EsJRilSpYZkNndCOjWfGZZYkY1Yyyz4I6Y76QswIv1A8ssybEoEf0syvzPbAMOhpRP83ejOwAAAABJRU5ErkJggg==>