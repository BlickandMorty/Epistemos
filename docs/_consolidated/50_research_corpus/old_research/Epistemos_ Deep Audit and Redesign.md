# **Architectural Audit and Ground-Up Redesign: Epistemos Knowledge Management System**

## **1\. Executive Summary**

The Epistemos application represents a highly ambitious implementation of local-first, intelligence-augmented knowledge management. By orchestrating a hybrid architecture across Swift 6, SwiftData, a Metal-based graph renderer, a Rust Foreign Function Interface (FFI) layer, and on-device Large Language Models (LLMs) via Apple Intelligence and Qwen 3.5B, the system achieves a sophisticated computational topology. The integration of an event-sourced temporal intelligence engine alongside a standard workspace state manager demonstrates a forward-thinking approach to session reconstruction and contextual awareness.

However, a rigorous architectural audit of the two engineering sessions—encompassing the Workspace System Foundation and Event-Sourced Temporal Intelligence—reveals critical stress points at the boundaries between these distinct technologies. Specifically, the synchronization between SwiftData's asynchronous context merging, the AppKit event loop, and the raw SQLite Write-Ahead Logging (WAL) implementations introduces concurrency hazards under Swift 6's strict isolation rules.1 Furthermore, the reliance on heuristic regex parsing for artificial intelligence command execution severely limits the reliability of the agentic workflows, resulting in cross-actor race conditions such as the identified note-opening defect.3

This comprehensive research report interrogates every facet of the current implementation. It spans Foreign Function Interface (FFI) boundaries, concurrency safety paradigms, storage serialization techniques, and AI orchestration patterns. The analysis provides a detailed diagnosis of existing vulnerabilities, resolves the critical state-synchronization bugs, and proposes a deeply researched ground-up redesign for the optimal next iteration of the Epistemos workspace intelligence system.

## **2\. Foreign Function Interface (FFI) and Computational Offloading**

The integration of a Rust engine via FFI provides significant computational advantages for operations constrained by Swift's standard library overhead, particularly in tight loops and large memory-bound traversals. Evaluating the optimal distribution of labor across this boundary is paramount.

## **2.1. Paragraph Hashing and SIMD Vectorization Throughput**

The ActivityTracker currently utilizes a deterministic FNV-1a algorithm implemented in Swift to hash paragraphs for semantic tracking.3 FNV-1a processes data as a scalar, byte-by-byte operation, making it structurally incapable of leveraging modern Single Instruction, Multiple Data (SIMD) instruction sets.5 While FNV-1a is adequate for minimal datasets, generating hashes for 100+ paragraphs (approximately 50KB to 100KB of text) on every keystroke idle cycle introduces measurable main-thread latency.6

Pushing this workload to Rust to utilize the xxHash3 algorithm via FFI offers a transformative performance gain. The xxHash3 algorithm leverages AVX2 and NEON SIMD instructions, processing 32 bytes concurrently rather than sequentially.7 This achieves throughput rates exceeding 31 GB/s in optimal conditions, fundamentally outpacing FNV-1a's scalar limitations.7

| Algorithm | Processing Strategy | Hardware Utilization | Throughput Estimate | Collision Quality |
| :---- | :---- | :---- | :---- | :---- |
| **FNV-1a (Swift)** | Scalar, Byte-by-byte | CPU ALU | \~0.55 GB/s | Moderate 10 |
| **xxHash3 (Rust)** | SIMD (AVX2/NEON) | Vector Registers | \~31.0 GB/s | Extremely High 7 |

The throughput difference for 100+ paragraphs will reduce hashing latency from roughly milliseconds to microseconds.8 To prevent FFI bridging overhead from negating this gain, the Swift side must pass UnsafeBufferPointer\<UInt8\> directly to the Rust boundary without duplicating the string memory into a new heap allocation.

## **2.2. Graph Structural Diffing: Swift Heuristics vs. Petgraph**

The TimeMachineService currently computes mass diffs by comparing scalar values, such as note word counts and graph node/edge counts, entirely within Swift.3 This heuristic approach fails to capture deep topological shifts in the knowledge graph. A user might delete an edge and create a new one simultaneously; the edge count remains static, but the semantic structure of the workspace has profoundly changed.

Transitioning the graph representation to Rust using the petgraph library allows for mathematically rigorous structural diffing. petgraph offers highly optimized memory layouts—such as Compressed Sparse Row (CSR) and contiguous Adjacency Matrices—that achieve unparalleled cache locality during traversal.11 Computing the structural delta between two graph states can be executed in ![][image1] time using Rust's zero-cost iterators.12 Swift-native graph diffing using standard dictionary-backed adjacency lists incurs high allocation overhead and scattered heap access, making real-time structural diffing prohibitively expensive.13 The Rust engine should hold the master graph state in memory, computing structural deltas internally and projecting only the modified bounds back to Swift.

## **2.3. SQLite Operations at the FFI Boundary**

The EventStore telemetry utilizes the raw SQLite3 C API directly within Swift.3 A theoretical alternative involves pushing these operations to Rust via rusqlite to achieve "lock-free" performance. However, architectural analysis indicates this adds unnecessary complexity. rusqlite is fundamentally a safe Rust wrapper over the identical underlying C API.14 Because the SQLite engine manages its own internal mutexes and locks at the C level, wrapping it in Rust does not yield performance advantages over Swift's direct C API bridging.14 The bottleneck in SQLite is disk I/O and statement compilation, neither of which are alleviated by shifting the binding language from Swift to Rust.

## **2.4. Adjacency List Serialization**

The WorkspaceSummaryService currently builds graph edge-lists by iterating the GraphStore in Swift, deliberately bounding the traversal to three neighbors to avoid blocking the main thread during AI prompt generation.3 If the master graph state is migrated to Rust, this process must become an FFI function. Instead of requesting nodes individually, the Swift layer should issue a single FFI call: get\_local\_topology\_edgelist(page\_id, max\_depth). The Rust engine, utilizing petgraph, traverses the CSR matrix and serializes the resulting sub-graph into a contiguous flatbuffer or delimited string before returning it across the FFI boundary, minimizing context switching overhead.

## **3\. Strict Concurrency, Isolation, and AppKit Thread Safety**

The enforcement of data-race safety in Swift 6 fundamentally disrupts older, unchecked patterns of memory sharing, demanding rigorous isolation and careful management of the AppKit event loop.

## **3.5. EventStore Pointer Safety and Isolation**

The EventStore is currently marked @unchecked Sendable with a nonisolated(unsafe) OpaquePointer to the SQLite database.3 Under Swift 6, nonisolated(unsafe) bypasses compiler diagnostics, transferring the entire burden of thread safety to the developer.15 While the database is opened with SQLITE\_OPEN\_FULLMUTEX (Serialized mode) and PRAGMA journal\_mode=WAL 3, making concurrent operations theoretically safe at the SQLite engine level, Swift's memory model remains unaware of these C-level guarantees.16

The @unchecked Sendable annotation must be eliminated to ensure long-term stability.2 The database pointer must be protected by a synchronization primitive. Implementing OSAllocatedUnfairLock or the newly introduced Swift 6 standard library Mutex allows the pointer to be encapsulated safely without triggering isolation violations.18 Alternatively, encapsulating the SQLite connection inside an explicit actor (e.g., EventStoreActor) ensures all queries and appends execute serially within that actor's isolation domain, eliminating pointer data races entirely and allowing the compiler to verify memory safety.16

## **3.6. AppKit Event Monitors and the Main Actor**

The ActivityTracker relies on NSEvent.addLocalMonitorForEvents to detect user idling. AppKit guarantees that local event monitors fire on the main thread.1 However, if the closure captures non-Sendable state and triggers asynchronous tasks, strict concurrency checking will flag potential data races.24 The closure does not necessarily require a @Sendable annotation if the encapsulating class is explicitly isolated to the @MainActor.25 By marking the tracker as @MainActor, the compiler understands that the closure and the state it mutates share the same execution context, thereby satisfying Swift 6's strict checks without forcing unnecessary structural changes.25

## **3.7. Asynchronous NSPanel Creation**

The GlobalOverlayController manages the QuitSavePanelController and other floating interfaces using a @MainActor designation.3 Creating an NSPanel from a @MainActor Task is generally safe and adheres to AppKit's strict requirement that all window manipulations occur on the main thread.3 However, architectural issues arise if the Task performs synchronous I/O or blocks the thread prior to appearance. The audit reveals that the onAppear block calls workspaceService.listWorkspaces(). If this fetch is synchronous against the SwiftData store, it will cause the main thread to hitch, delaying the panel's presentation and resulting in a stuttering user experience.3 All data hydration required for panel presentation must be fully asynchronous.

## **3.8. Focus Mechanics in Borderless Floating Panels**

The floating panel utilizes a KeyablePanel: NSPanel subclass, overriding canBecomeKey \= true to allow text input.3 While this is the standard method to force a borderless panel to accept keyboard events, it introduces significant focus theft issues in macOS. If the panel becomes Key, it forcibly steals focus from the underlying NSTextStorage editor, interrupting the user's workflow if the panel was meant to be purely an overlay.26

To prevent focus theft while allowing the overlay to intercept commands conditionally, the panel must utilize self.ignoresMouseEvents \= true for areas outside the text field.28 Furthermore, overriding needsPanelToBecomeKey dynamically based on the active SwiftUI @FocusState prevents the panel from permanently trapping the responder chain.29 For hover effects over the text field beneath the panel, the system should rely on CGEventTap to track cursor coordinates globally, rather than relying on the panel's internal hit-testing, which interferes with the window below.26

## **4\. Storage Topologies, Serialization, and Persistence**

The efficiency of telemetry storage and snapshot serialization dictates the overall responsiveness of the temporal intelligence system.

## **4.9. Telemetry Store: SQLite C API vs. GRDB**

The EventStore manually binds sqlite3 types using raw C API calls.3 This is highly error-prone, circumvents Swift's type safety, and requires manual management of statement finalization and memory allocation. Replacing the raw C API with GRDB is strongly recommended.31 GRDB provides a DatabasePool designed specifically for WAL mode, enabling lock-free concurrent reads alongside a serialized background writer.32 GRDB achieves performance near the theoretical limits of raw SQLite by leveraging static column indexing, outperforming custom manual wrappers while drastically reducing boilerplate and eliminating pointer management risks.14

## **4.10. Binary Serialization for Workspace Snapshots**

The WorkspaceSnapshot encodes to a growing JSON blob, potentially exceeding 50KB as the workspace scales. The synchronous JSONEncoder blocks the main thread during the auto-save sequence.3 JSON parsing requires heavy string allocation and recursive character interpretation, which is inefficient for high-frequency state snapshots.35

Transitioning to a binary format such as FlatBuffers or MessagePack is essential. FlatBuffers allows for zero-copy deserialization; the struct maps directly onto the binary buffer residing in memory, bypassing the parsing phase entirely. This architectural advantage reduces deserialization latency from 4.43 milliseconds (JSON) to approximately 0.02 milliseconds.36 While MessagePack offers smaller payloads and encodes \~3x faster than JSON 36, FlatBuffers is superior for large, frequently read snapshot blobs where the application must read specific nested fields (e.g., cursor positions) without deserializing the entire document.35

## **4.11. FetchDescriptor Latency and In-Memory Indexing**

The SessionIntelligence agent's executeCommand relies on FetchDescriptor\<SDPage\> queries against the SwiftData ModelContext on every command to find notes by title.3 Executing Core Data or SwiftData fetches synchronously in a tight command-parsing loop introduces extreme latency overhead and risks disk I/O bottlenecks.39 SwiftData is not designed for high-frequency ![][image2] string lookups.40

An actor-isolated prefix trie or a simple dictionary (\`\`) must be maintained in-memory. This index should be hydrated on application launch and updated incrementally via SwiftData observation notifications or ModelContext.didSave events.40 This decouples the LLM's spatial lookup capabilities from disk I/O, allowing instant command resolution.

## **4.12. Dual-Write Safety During App Termination**

The EpistemosApp.swift utilizes the applicationShouldTerminate hook to intercept the quit process, returning .terminateLater.3 The performTeardown block sequentially calls workspaceService.autoSave() (SwiftData) and EventStore closures (SQLite).3 While this sequential approach mitigates basic data loss, it is not atomically safe. If the process is forcefully killed by the operating system (e.g., due to a thermal event or memory limit) between the SwiftData commit and the SQLite WAL sync, the two databases will experience temporal drift, leading to corrupt historical reconstructions upon the next launch.

Implementing a distributed saga pattern or a two-phase commit is excessive for local storage. Instead, the EventStore must record a strict TEARDOWN\_START and TEARDOWN\_COMPLETE event. Upon the next launch, the system can inspect the tail of the event log. If TEARDOWN\_COMPLETE is missing, the system detects an incomplete shutdown and executes a conflict-resolution protocol, reconciling the SwiftData state with the last known reliable SQLite snapshot.

## **5\. Artificial Intelligence Orchestration and Context Design**

The architecture integrates Apple Intelligence for rapid, secure, per-window summarization and Qwen 3.5B for complex global synthesis and agentic commands. Optimizing how data flows into and out of these models dictates their efficacy.

## **5.13. Concurrent Map-Reduce Processing**

The WorkspaceSummaryService currently executes the Map phase sequentially, processing up to 8 open windows one by one using Apple Intelligence.3 Calling Apple Intelligence sequentially severely underutilizes the hardware capabilities of the Neural Engine (NPU). The Map phase must be refactored to utilize a Swift TaskGroup, fanning out the summarization requests concurrently.41 This allows the macOS operating system to dynamically schedule the inference workloads across available execution units, drastically reducing the total wall-clock time required for context building.

## **5.14. Context Structuring: JSON vs. Plain Text**

The buildWorkspaceAwarenessContext function concatenates graph edge-lists and paragraph diffs into a flat string.3 While plain text is marginally more token-efficient, it leads to severe "attention dilution" in smaller models like Qwen 3.5B. LLMs are explicitly pre-trained on vast repositories of structured code.42 Injecting the workspace context as a strict JSON or YAML object allows the model to leverage its structural priors, drastically reducing hallucinations regarding which node is connected to which, and allowing it to navigate the semantic diffs with programmatic precision.42

## **5.15. Intent Classification, Regex Fallbacks, and Native Tool Calling**

The current executeCommand logic relies on hardcoded string prefixes and regex fallbacks to parse commands like .3 This is a fundamentally brittle paradigm. If the LLM generates a slight variation, such as , or includes trailing spaces, the regex parser silently fails, abandoning the execution loop.43

Qwen 3.5B and later models possess native "tool calling" (function calling) capabilities.44 The model should be provided with a JSON schema defining the available functions (e.g., create\_note(title, content), navigate\_graph(node\_id)). When the model decides to act, it generates a structured JSON payload in a dedicated tool\_calls output block rather than emitting inline text. This eliminates the need for regex parsing, providing guaranteed argument extraction, and allowing the application to serialize the output directly into executable Swift structs.4

## **5.16. Streaming Context and SwiftData Fetch Blocks**

The deep context mode reads SDChat messages with a SwiftData fetch inside the generation loop.3 The audit of ChatCoordinator.swift reveals that SwiftData fetches are currently deferred to the .completed phase of the streaming loop, avoiding I/O operations during the .textDelta phase.3 This correctly prevents the Main Actor from being blocked while actively rendering text. However, fetching historical chat context prior to initiating the stream must also be offloaded. Performing synchronous fetches to build the workspaceAwarenessContext on the main thread prior to pipeline execution will cause a noticeable delay between the user pressing enter and the first token appearing. All context-gathering queries must be executed within an isolated background ModelActor before the stream is initiated.47

## **6\. User Experience, Interface Mechanics, and Spatial Design**

## **6.17. Patterns of Magical AI Control**

Applications that successfully implement "AI that controls the app" (such as Copilot in VS Code or Raycast AI) share specific UX patterns that distinguish them from gimmicky chatbots. The feeling of "magic" is derived from determinism, speed, and interruptibility. When an AI agent performs an action, the UI must immediately reflect the intended state (optimistic UI updating) rather than waiting for background processing. Furthermore, the user must be able to cancel an ongoing multi-step agentic action instantly. If the Qwen 3.5B agent decides to create five interconnected notes, the system must expose a visible execution queue that the user can pause or revert.

## **6.18. Intent Classification Models**

While native tool calling is the optimal path for LLM-generated commands, user-generated natural language commands in the SessionIntelligence overlay should not rely on exact prefix matching.3 Deploying a tiny, quantized intent classification model (e.g., a sub-100M parameter BERT variant) running via Core ML can instantly route user queries like "start a new page about physics" to the correct tool execution pathway without requiring the heavy overhead of the Qwen 3.5B generative model.

## **6.19. The Semantic Scrub Bar via Metal Shaders**

Implementing the "Semantic Scrub Bar" for the Time Machine UI requires a visual representation of event density mapped to a timeline. Standard SwiftUI components cannot render dense, pixel-perfect heatmaps representing thousands of events at 60 FPS without immense CPU overhead and view hierarchy bloat.49

A custom Metal shader is the optimal architectural choice.50 By compiling the SQLite event timestamps into a 1D texture or passing them via an Argument Buffer to a Metal fragment shader, the GPU can compute the temporal density and map it to a color gradient in real-time.50 The Metal Shader Converter can streamline the integration of this pipeline.52 A SwiftUI MetalView (via NSViewRepresentable) overlaying the standard timeline component provides the required rendering performance while keeping the interactive layout hierarchy declarative.49

## **6.20. Progressive Disclosure in Welcome-Back Overlays**

The current implementation auto-dismisses the welcome-back session overlay after 12 seconds. This violates the principles of user-driven spatial awareness. If the user context-switches to another application before reading the summary, the intelligence is lost. The overlay should persist until explicitly dismissed or interacted with. It should employ progressive disclosure: initially presenting a dense, two-sentence synthesis, expanding into a detailed semantic diff of changes upon cursor hover, and offering an explicit button to instantiate the full session summary as a permanent note within the knowledge graph.

## **6.22. Floating Panel Hierarchy Conflicts**

The floating panel system creates windows at the .floating \+ 1 level to ensure they appear above all standard application windows.3 However, continuously placing panels at elevated NSWindow.Level raw values introduces conflicts with system-level overlays in macOS, such as the Notification Center or Control Center. To avoid trapping the user in an inescapable UI state, the panel level should utilize standard AppKit constants (e.g., .popUpMenu or .modalPanel) rather than arbitrary arithmetic additions, ensuring the OS compositor correctly orders the application's overlays relative to system critical alerts.

## **7\. Security, Integrity, and Race Conditions**

## **7.21. Encrypting the Telemetry Store**

The SQLite EventStore currently logs raw chat message snippets, semantic diffs, and workspace telemetry in plain text.3 For a privacy-first, local-only application, storing potentially sensitive user knowledge graphs in an unencrypted database is a significant vulnerability.

The integration of SQLCipher is a mandatory security requirement. Benchmarks indicate that utilizing SQLCipher introduces a negligible performance overhead of approximately 5% to 15% for general read and write operations, which is vastly outweighed by the security benefits.55 The database decryption key can be securely derived and stored within the macOS Secure Enclave via the Keychain, ensuring that idle telemetry cannot be scraped from the disk by malicious actors or unauthorized access.

## **7.23. Text Storage Race Conditions**

The NoteFileStorage.writeBody function interacts directly with the file system or underlying persistence layer when the AI agent modifies a note. If this function is invoked while the NoteWindowManager holds an active NSTextStorage for the same document, a severe race condition occurs.3 AppKit's NSTextStorage is strictly bound to the main thread and expects all mutations to route through its internal delegate system to trigger layout and display updates.

The AI command executor must never write to disk directly if the note is active in memory. Instead, the AI agent must post a unified StateMutationIntent to the main actor. The NoteWindowManager intercepts this intent, programmatically applies the edits via the NSTextStorage.replaceCharacters(in:with:) API to preserve undo history and cursor position, and subsequently allows the standard editor auto-save mechanism to persist the changes to the VaultSyncService.

## **8\. Resolution of Critical State-Synchronization Defects**

The most critical UX bug identified in the audit manifests as the AI agent confidently stating, "Created and opened note: X", while failing to render the window. This defect immediately erodes user trust and is a classic symptom of context merging latency and actor isolation failure within the SwiftData framework.

## **8.1. Diagnosis of the Failure Mode**

The executeCommand function initiates a command resolution flow.3 When it routes to the createPage() command, the VaultSyncService initializes an SDPage entity and inserts it into the ModelContext. Immediately following this, the system executes NoteWindowManager.shared.open(pageId:).3

The failure occurs due to the asynchronous nature of SwiftData's PersistentIdentifier generation and the rigid isolation boundaries of nested contexts 47:

1. **Context Misalignment:** If the agent executes the creation logic on a background ModelActor to prevent blocking the UI during AI generation, the newly instantiated SDPage exists solely within that background context.48  
2. **Delayed Merging:** The @MainActor isolated NoteWindowManager attempts to fetch the note by its pageId. However, the background context has not yet saved the data to the SQLite persistent store, or the main context has not yet processed the didSave notification to merge the changes into its memory space.58  
3. **The needsVaultSync Cascade:** Furthermore, the engineering documentation dictates that setting page.needsVaultSync \= true triggers complex @Query refetches.3 If the open(pageId:) request fires before the SwiftData try modelContext.save() completes its disk flush and updates the main context's cache, the fetch returns nil, and the window manager silently aborts the operation.3

## **8.2. Remediation Strategy**

To resolve this synchronization drift, the system must enforce a synchronous yield pattern across the actor boundary, ensuring database persistence is guaranteed before UI invocation.

First, an explicit try modelContext.save() must be invoked immediately after insertion inside VaultSyncService.createPage().3 Second, the system must not attempt to pass the SDPage object across actors, as Core Data/SwiftData models are not Sendable.47 Instead, the execution flow must extract the PersistentIdentifier generated post-save. Finally, the agent execution loop must yield to the Main Actor and strictly await the context merge before commanding the window manager.

Swift

// Within the agentic executor loop running on a background Task  
let newPageId \= try await backgroundModelActor.createAndSaveNote(title: targetTitle)

// Yield execution and explicitly transition to the Main Actor  
await MainActor.run {  
    // Force the main context to process pending background saves  
    try? mainContext.save()   
      
    // The identifier is now guaranteed to exist in the main context cache  
    NoteWindowManager.shared.open(pageId: newPageId)  
}

This architectural pattern forces deterministic execution, completely eliminating the race condition and restoring trust in the AI's feedback loop.

## **9\. Ground-Up Redesign Blueprint**

If the Epistemos system were to be completely re-architected from the ground up for the macOS environment utilizing Swift 6, Rust FFI, and local AI orchestration, the following structural paradigms must be adopted to achieve peak performance, absolute thread-safety, and agentic reliability.

## **9.1. Unified Event Sourcing via GRDB**

Instead of separating SDWorkspace state management and the SQLite EventStore, the entire application must embrace a unified Event Sourcing architecture built fundamentally upon GRDB.31

The raw SQLite C API limits swift-native concurrency and risks pointer mismanagement. By implementing GRDB's DatabasePool with WAL mode 32, the system allows for an arbitrary number of concurrent readers (e.g., the UI, the graph renderer) while a single, strictly serialized background writer appends telemetry events. Rather than constantly mutating a rigid SDWorkspace model, the system state becomes a pure, deterministic projection of the event log.

## **9.2. SIMD Paragraph Tracking**

The telemetry engine should dispatch text delta buffers across the FFI boundary to Rust. Rust, utilizing the heavily optimized xxHash3 SIMD implementation 8, processes the paragraph chunks at memory-bandwidth limits (upwards of 31GB/s). It computes the deterministic hashes and bridges only the resulting 64-bit integer array back to Swift for persistence. This eliminates all hashing-related latency from the Swift Main Actor.

## **9.3. Intelligent AI Routing**

Apple Intelligence must be strictly relegated to background micro-tasks, such as entity extraction or one-sentence node summaries, utilizing TaskGroup concurrency to maximize NPU saturation.41 The local Qwen 3.5B model assumes control over complex global synthesis and spatial reasoning. Potential cloud models should only be invoked if the user explicitly requests deep research requiring vast parameter knowledge outside the scope of the local workspace graph.

## **9.4. State Reconstruction via RFC 6902**

The TimeMachineService currently attempts to reconstruct history by comparing full JSON snapshots. As the database grows, deserializing large blobs induces severe memory pressure and latency. The optimal redesign utilizes JSON Patch (RFC 6902\) for incremental delta storage.62 Instead of saving a 50KB WorkspaceSnapshot every 30 seconds, the system computes the diff between the previous and current state, storing only the discrete operations (e.g., {"op": "replace", "path": "/cursor/position", "value": 142}). When reconstructing a historical state, the engine fetches the nearest absolute snapshot (stored efficiently in FlatBuffers 35) and sequentially applies the RFC 6902 operations. This reduces disk I/O exponentially and allows the Time Machine UI to scrub through time at 60 FPS without hitching.

## **9.5. Multi-Agent Planning Framework**

The reliance on sequential pipelines and regex-based command parsing prevents the AI from achieving true autonomy. The system must transition to a Multi-Agent Orchestration Framework 65 specifically tailored for the local Qwen 3.5B model's native capabilities.45

Instead of a single prompt, the interaction is broken into a loop: Goal ![][image3] Plan ![][image3] Act ![][image3] Observe ![][image3] Done.67 The Qwen model is provided with a strict JSON schema defining system tools 44 (e.g., create\_note(title), write\_content(id, text)). When Qwen outputs a tool\_call 4, the Swift execution engine intercepts the JSON, decodes it into a strongly-typed struct, executes the file-system mutation, and feeds the resulting state back into the LLM as an observation.67 This loop continues autonomously until the LLM achieves the user's multi-step request, executed with mathematical reliability.

## **9.6. Next-Generation Graph Differencing**

The Swift-native knowledge graph iteration logic must be deprecated. A complete redesign pushes the entire graph topology into a Rust backend utilizing petgraph.11 By storing the graph as a Compressed Sparse Row (CSR) matrix in Rust, adjacency lookups become purely contiguous array reads. When a node is modified, the Swift side sends a lightweight notification to the Rust backend. The Rust engine utilizes petgraph's ![][image1] traversal algorithms to compute the structural delta.12 It then serializes only the sub-graph relevant to the active windows into an edge-list, passing it back to Swift for AI context injection. This abstracts the immense computational weight of graph theory mechanics entirely away from the AppKit render loop.

## **10\. Strategic Conclusions**

The Epistemos architecture is conceptually brilliant, pushing the boundaries of what is possible within a localized, privacy-preserving macOS environment. The utilization of hybrid compilation targets (Swift/Rust) and local AI orchestration positions the application at the vanguard of modern software engineering.

However, the transition from a prototype to a production-grade application requires shedding legacy heuristics. Regex-based command parsing must be eradicated in favor of native tool-calling JSON schemas. The unchecked memory assumptions surrounding raw SQLite pointers must yield to strict Swift 6 Mutex primitives or GRDB's highly optimized WAL pools. Finally, managing cross-actor state synchronization within SwiftData demands explicit serialization and deterministic yields to the Main Actor.

By adopting this ground-up redesign—anchoring the system in Event Sourcing, offloading topological and hashing computations to Rust SIMD vectors, and empowering the Qwen model with a true multi-agent planning framework—the system will achieve unprecedented performance, absolute thread safety, and a genuinely robust user experience.

#### **Works cited**

1. Adopting strict concurrency in Swift 6 apps | Apple Developer Documentation, accessed March 23, 2026, [https://developer.apple.com/documentation/swift/adoptingswift6](https://developer.apple.com/documentation/swift/adoptingswift6)  
2. Unexpected Behavior with SWIFT\_STRICT\_CONCURRENCY \= complete in Xcode 26 (Swift 6\) \- Compiler, accessed March 23, 2026, [https://forums.swift.org/t/unexpected-behavior-with-swift-strict-concurrency-complete-in-xcode-26-swift-6/82672](https://forums.swift.org/t/unexpected-behavior-with-swift-strict-concurrency-complete-in-xcode-26-swift-6/82672)  
3. CLAUDE.md  
4. Advanced Function Calling and Multi-Agent Systems with Small Language Models in Foundry Local \- Microsoft Tech Community, accessed March 23, 2026, [https://techcommunity.microsoft.com/blog/educatordeveloperblog/advanced-function-calling-and-multi-agent-systems-with-small-language-models-in-/4481180](https://techcommunity.microsoft.com/blog/educatordeveloperblog/advanced-function-calling-and-multi-agent-systems-with-small-language-models-in-/4481180)  
5. You can get higher quality and throughput for short strings from a hash that u... | Hacker News, accessed March 23, 2026, [https://news.ycombinator.com/item?id=32400478](https://news.ycombinator.com/item?id=32400478)  
6. Hashing \- The Rust Performance Book, accessed March 23, 2026, [https://nnethercote.github.io/perf-book/hashing.html](https://nnethercote.github.io/perf-book/hashing.html)  
7. WyHash, Fnv1, Murmurhash3, City hash, and xxHash with Rust \- Asecuritysite.com, accessed March 23, 2026, [https://asecuritysite.com/hash2/rust\_non\_crypto](https://asecuritysite.com/hash2/rust_non_crypto)  
8. FNV-1a vs xxHash | Compare Leading Cryptographic Hashing Algorithms \- SSOJet, accessed March 23, 2026, [https://ssojet.com/compare-hashing-algorithms/fnv-1a-vs-xxhash](https://ssojet.com/compare-hashing-algorithms/fnv-1a-vs-xxhash)  
9. FNV-1a vs xxHash | Compare Top Cryptographic Hashing Algorithms \- MojoAuth, accessed March 23, 2026, [https://mojoauth.com/compare-hashing-algorithms/fnv-1a-vs-xxhash](https://mojoauth.com/compare-hashing-algorithms/fnv-1a-vs-xxhash)  
10. Comparing xxHash with FNV is a strawman, it's apples and oranges in terms of qua... | Hacker News, accessed March 23, 2026, [https://news.ycombinator.com/item?id=10674981](https://news.ycombinator.com/item?id=10674981)  
11. Graphs in Rust: An Introduction to Petgraph | Depth-First, accessed March 23, 2026, [https://depth-first.com/articles/2020/02/03/graphs-in-rust-an-introduction-to-petgraph/](https://depth-first.com/articles/2020/02/03/graphs-in-rust-an-introduction-to-petgraph/)  
12. petgraph \- Rust \- Docs.rs, accessed March 23, 2026, [https://docs.rs/petgraph/](https://docs.rs/petgraph/)  
13. Performance Comparison of Graph Representations Which Support Dynamic Graph Updates \- arXiv, accessed March 23, 2026, [https://arxiv.org/html/2502.13862v1](https://arxiv.org/html/2502.13862v1)  
14. Yes. GRDB encourages Codable because the user can profit from the code generated... | Hacker News, accessed March 23, 2026, [https://news.ycombinator.com/item?id=45279755](https://news.ycombinator.com/item?id=45279755)  
15. Safely Using nonisolated(unsafe) to Incrementally Adopt Swift's Strict Concurrency Model, accessed March 23, 2026, [https://medium.com/@aliyasirali/understanding-nonisolated-unsafe-in-swift-incremental-adoption-of-strict-concurrency-2cbb61c9adf4](https://medium.com/@aliyasirali/understanding-nonisolated-unsafe-in-swift-incremental-adoption-of-strict-concurrency-2cbb61c9adf4)  
16. Actors, Threading and SQLite \- Discussion \- Swift Forums, accessed March 23, 2026, [https://forums.swift.org/t/actors-threading-and-sqlite/49710](https://forums.swift.org/t/actors-threading-and-sqlite/49710)  
17. Swift 6 strict concurrency : r/swift \- Reddit, accessed March 23, 2026, [https://www.reddit.com/r/swift/comments/1icj54z/swift\_6\_strict\_concurrency/](https://www.reddit.com/r/swift/comments/1icj54z/swift_6_strict_concurrency/)  
18. \`Sychronization.Mutex  
19. OSAllocatedUnfairLock | Apple Developer Documentation, accessed March 23, 2026, [https://developer.apple.com/documentation/os/osallocatedunfairlock](https://developer.apple.com/documentation/os/osallocatedunfairlock)  
20. Beware of os\_unfair\_lock \- mcky.dev, accessed March 23, 2026, [https://mcky.dev/blog/beware-os-unfair/](https://mcky.dev/blog/beware-os-unfair/)  
21. Swift access race with os\_unfair\_lock\_lock \- Stack Overflow, accessed March 23, 2026, [https://stackoverflow.com/questions/68614552/swift-access-race-with-os-unfair-lock-lock](https://stackoverflow.com/questions/68614552/swift-access-race-with-os-unfair-lock-lock)  
22. Swift Synchronization Mechanisms | My awesome title, accessed March 23, 2026, [https://jano.dev/apple/mach-o/2024/12/07/Swift-Synchronization-Mechanisms.html](https://jano.dev/apple/mach-o/2024/12/07/Swift-Synchronization-Mechanisms.html)  
23. Static var concurrency checking within Actor \- Using Swift, accessed March 23, 2026, [https://forums.swift.org/t/static-var-concurrency-checking-within-actor/79573](https://forums.swift.org/t/static-var-concurrency-checking-within-actor/79573)  
24. Complete SWIFT\_STRICT\_CONCURRENCY does not show errors for non thread-safe code, accessed March 23, 2026, [https://stackoverflow.com/questions/79851066/complete-swift-strict-concurrency-does-not-show-errors-for-non-thread-safe-code](https://stackoverflow.com/questions/79851066/complete-swift-strict-concurrency-does-not-show-errors-for-non-thread-safe-code)  
25. Understanding the New Swift 6 Concurrency Features | by Anand Nimje \- Medium, accessed March 23, 2026, [https://medium.com/@nimjea/understanding-the-new-swift-6-concurrency-features-3bff267426cc](https://medium.com/@nimjea/understanding-the-new-swift-6-concurrency-features-3bff267426cc)  
26. NSPanel: How to not steal text field focus and get mouse hover event? : r/swift \- Reddit, accessed March 23, 2026, [https://www.reddit.com/r/swift/comments/14vn5q3/nspanel\_how\_to\_not\_steal\_text\_field\_focus\_and\_get/](https://www.reddit.com/r/swift/comments/14vn5q3/nspanel_how_to_not_steal_text_field_focus_and_get/)  
27. How can I make my borderless Window be the Key Window after launch? \- Stack Overflow, accessed March 23, 2026, [https://stackoverflow.com/questions/75736964/how-can-i-make-my-borderless-window-be-the-key-window-after-launch](https://stackoverflow.com/questions/75736964/how-can-i-make-my-borderless-window-be-the-key-window-after-launch)  
28. NSPanel: How to not steal text field focus and get mouse hover ..., accessed March 23, 2026, [https://www.reddit.com/r/swift/comments/14vn5q3/nspanel-how-to-not\_steal\_text\_field\_focus\_and\_get/](https://www.reddit.com/r/swift/comments/14vn5q3/nspanel-how-to-not_steal_text_field_focus_and_get/)  
29. needsPanelToBecomeKey | Apple Developer Documentation, accessed March 23, 2026, [https://developer.apple.com/documentation/appkit/nsview/needspaneltobecomekey](https://developer.apple.com/documentation/appkit/nsview/needspaneltobecomekey)  
30. becomesKeyOnlyIfNeeded | Apple Developer Documentation, accessed March 23, 2026, [https://developer.apple.com/documentation/appkit/nspanel/becomeskeyonlyifneeded](https://developer.apple.com/documentation/appkit/nspanel/becomeskeyonlyifneeded)  
31. Raw SQL in iOS/Swift: SQLite.swift or GRDB? : r/iOSProgramming \- Reddit, accessed March 23, 2026, [https://www.reddit.com/r/iOSProgramming/comments/1d7a0zr/raw\_sql\_in\_iosswift\_sqliteswift\_or\_grdb/](https://www.reddit.com/r/iOSProgramming/comments/1d7a0zr/raw_sql_in_iosswift_sqliteswift_or_grdb/)  
32. GitHub \- groue/GRDB.swift: A toolkit for SQLite databases, with a focus on application development, accessed March 23, 2026, [https://github.com/groue/GRDB.swift](https://github.com/groue/GRDB.swift)  
33. Performance · groue/GRDB.swift Wiki \- GitHub, accessed March 23, 2026, [https://github.com/groue/GRDB.swift/wiki/Performance](https://github.com/groue/GRDB.swift/wiki/Performance)  
34. GRDB vs SwiftData vs Realm vs ?? : r/iOSProgramming \- Reddit, accessed March 23, 2026, [https://www.reddit.com/r/iOSProgramming/comments/1oesuhn/grdb\_vs\_swiftdata\_vs\_realm\_vs/](https://www.reddit.com/r/iOSProgramming/comments/1oesuhn/grdb_vs_swiftdata_vs_realm_vs/)  
35. Benchmarking Data Serialization: JSON vs. Protobuf vs. Flatbuffers | by Harshil Jani, accessed March 23, 2026, [https://medium.com/@harshiljani2002/benchmarking-data-serialization-json-vs-protobuf-vs-flatbuffers-3218eecdba77](https://medium.com/@harshiljani2002/benchmarking-data-serialization-json-vs-protobuf-vs-flatbuffers-3218eecdba77)  
36. Binary Serialization Formats \- by Shekhar Manna \- Medium, accessed March 23, 2026, [https://medium.com/@shekhar.manna83/binary-serialization-formats-e2703f053010](https://medium.com/@shekhar.manna83/binary-serialization-formats-e2703f053010)  
37. Benchmarks \- FlatBuffers Docs, accessed March 23, 2026, [https://flatbuffers.dev/benchmarks/](https://flatbuffers.dev/benchmarks/)  
38. Benchmarking Eight Serialization Formats in C and C++ (JSON, BSON, CBOR, flexbuffers, msgpack, TOML, XML, YAML) : r/cpp \- Reddit, accessed March 23, 2026, [https://www.reddit.com/r/cpp/comments/1drz3eg/benchmarking\_eight\_serialization\_formats\_in\_c\_and/](https://www.reddit.com/r/cpp/comments/1drz3eg/benchmarking_eight_serialization_formats_in_c_and/)  
39. FetchDescriptor | Apple Developer Documentation, accessed March 23, 2026, [https://developer.apple.com/documentation/swiftdata/fetchdescriptor](https://developer.apple.com/documentation/swiftdata/fetchdescriptor)  
40. ios \- How do I refresh a SwiftData (manual) fetch whenever the ..., accessed March 23, 2026, [https://stackoverflow.com/questions/79743735/how-do-i-refresh-a-swiftdata-manual-fetch-whenever-the-database-is-changed](https://stackoverflow.com/questions/79743735/how-do-i-refresh-a-swiftdata-manual-fetch-whenever-the-database-is-changed)  
41. How to Use Swift Concurrency with async/await \- OneUptime, accessed March 23, 2026, [https://oneuptime.com/blog/post/2026-02-03-swift-async-await/view](https://oneuptime.com/blog/post/2026-02-03-swift-async-await/view)  
42. Beyond Natural Language: LLMs Leveraging Alternative Formats for Enhanced Reasoning and Communication \- arXiv.org, accessed March 23, 2026, [https://arxiv.org/html/2402.18439v3](https://arxiv.org/html/2402.18439v3)  
43. Uncovering the Impact of Chain-of-Thought Reasoning for Direct Preference Optimization: Lessons from Text-to-SQL \- ACL Anthology, accessed March 23, 2026, [https://aclanthology.org/2025.acl-long.1031.pdf](https://aclanthology.org/2025.acl-long.1031.pdf)  
44. Function Calling \- Qwen, accessed March 23, 2026, [https://qwen.readthedocs.io/en/stable/framework/function\_call.html](https://qwen.readthedocs.io/en/stable/framework/function_call.html)  
45. Build a Local AI Agent with Qwen 3.5 Small on macOS \- GetStream.io, accessed March 23, 2026, [https://getstream.io/blog/qwen3-local-ai-agent/](https://getstream.io/blog/qwen3-local-ai-agent/)  
46. GitHub \- QwenLM/Qwen-Agent: Agent framework and applications built upon Qwen\>=3.0, featuring Function Calling, MCP, Code Interpreter, RAG, Chrome extension, etc., accessed March 23, 2026, [https://github.com/QwenLM/Qwen-Agent](https://github.com/QwenLM/Qwen-Agent)  
47. How to access SwiftData from a background thread? \- Apple Developer, accessed March 23, 2026, [https://developer.apple.com/forums/thread/763500](https://developer.apple.com/forums/thread/763500)  
48. SwiftData Background Tasks \- Use Your Loaf, accessed March 23, 2026, [https://useyourloaf.com/blog/swiftdata-background-tasks/](https://useyourloaf.com/blog/swiftdata-background-tasks/)  
49. Creating a timeline video editor in pure SwiftUI \- Reddit, accessed March 23, 2026, [https://www.reddit.com/r/SwiftUI/comments/1jbuesh/creating\_a\_timeline\_video\_editor\_in\_pure\_swiftui/](https://www.reddit.com/r/SwiftUI/comments/1jbuesh/creating_a_timeline_video_editor_in_pure_swiftui/)  
50. Analyzing Apple GPU performance with performance heat maps \- Apple Developer, accessed March 23, 2026, [https://developer.apple.com/documentation/xcode/analyzing-apple-gpu-performance-using-performance-heatmaps-a17-m3/](https://developer.apple.com/documentation/xcode/analyzing-apple-gpu-performance-using-performance-heatmaps-a17-m3/)  
51. Taking First Steps into Metal Shaders \- Create with Swift, accessed March 23, 2026, [https://www.createwithswift.com/taking-first-steps-into-metal-shaders/](https://www.createwithswift.com/taking-first-steps-into-metal-shaders/)  
52. Get started with Metal shader converter \- Apple Developer, accessed March 23, 2026, [https://developer.apple.com/metal/shader-converter/](https://developer.apple.com/metal/shader-converter/)  
53. WWDC23: Bring your game to Mac, Part 2: Compile your shaders | Apple \- YouTube, accessed March 23, 2026, [https://www.youtube.com/watch?v=6gQxhsZsawc](https://www.youtube.com/watch?v=6gQxhsZsawc)  
54. MetalGraph: a new way of working with Metal shaders for SwiftUI | by Victor Baro | Medium, accessed March 23, 2026, [https://medium.com/@victorbaro/metalgraph-a-new-way-of-working-with-metal-shaders-for-swiftui-bed1cf1a2b81](https://medium.com/@victorbaro/metalgraph-a-new-way-of-working-with-metal-shaders-for-swiftui-bed1cf1a2b81)  
55. SQLCipher Performance Optimization \- Guidelines for Enhancing Application Performance with Full Database Encryption \- Zetetic LLC, accessed March 23, 2026, [https://www.zetetic.net/sqlcipher/performance/](https://www.zetetic.net/sqlcipher/performance/)  
56. Spiking SQLCipher for Room \- Surprising Benchmark Results, accessed March 23, 2026, [https://discuss.zetetic.net/t/spiking-sqlcipher-for-room-surprising-benchmark-results/6961](https://discuss.zetetic.net/t/spiking-sqlcipher-for-room-surprising-benchmark-results/6961)  
57. sqlite \- IS Encrypting the whole database more secure than encrypting the data only?, accessed March 23, 2026, [https://stackoverflow.com/questions/68988382/is-encrypting-the-whole-database-more-secure-than-encrypting-the-data-only](https://stackoverflow.com/questions/68988382/is-encrypting-the-whole-database-more-secure-than-encrypting-the-data-only)  
58. Swiftdata update from background context. : r/iOSProgramming \- Reddit, accessed March 23, 2026, [https://www.reddit.com/r/iOSProgramming/comments/1aeanj1/swiftdata\_update\_from\_background\_context/](https://www.reddit.com/r/iOSProgramming/comments/1aeanj1/swiftdata_update_from_background_context/)  
59. Fetch data from Background Thread with SwiftData | by Sebastien fernandez \- Medium, accessed March 23, 2026, [https://medium.com/@sebasf8/swiftdata-fetch-from-background-thread-c8d9fdcbfbbe](https://medium.com/@sebasf8/swiftdata-fetch-from-background-thread-c8d9fdcbfbbe)  
60. Taking SwiftData Further: @ModelActor, Swift Concurrency, and Avoiding @MainActor Pitfalls | by Maksym Horobets | Medium, accessed March 23, 2026, [https://medium.com/@killlilwinters/taking-swiftdata-further-modelactor-swift-concurrency-and-avoiding-mainactor-pitfalls-3692f61f2fa1](https://medium.com/@killlilwinters/taking-swiftdata-further-modelactor-swift-concurrency-and-avoiding-mainactor-pitfalls-3692f61f2fa1)  
61. Is SwiftData very brittle or am I using it wrong? : r/swift \- Reddit, accessed March 23, 2026, [https://www.reddit.com/r/swift/comments/1kyn98x/is\_swiftdata\_very\_brittle\_or\_am\_i\_using\_it\_wrong/](https://www.reddit.com/r/swift/comments/1kyn98x/is_swiftdata_very_brittle_or_am_i_using_it_wrong/)  
62. JSON Whisperer: Efficient JSON Editing with LLMs \- arXiv, accessed March 23, 2026, [https://arxiv.org/html/2510.04717v1](https://arxiv.org/html/2510.04717v1)  
63. SylphxAI/zen-json-patch: JSON Patch utilities for Zen \- RFC 6902 compliant state updates, accessed March 23, 2026, [https://github.com/SylphxAI/zen-json-patch](https://github.com/SylphxAI/zen-json-patch)  
64. JSON Patch vs JSON Merge Patch \- In-Depth Comparison \- Zuplo, accessed March 23, 2026, [https://zuplo.com/learning-center/json-patch-vs-json-merge-patch](https://zuplo.com/learning-center/json-patch-vs-json-merge-patch)  
65. Enterprise AI Agents: Agentic Design Patterns Explained \- Tungsten Automation, accessed March 23, 2026, [https://www.tungstenautomation.com/learn/blog/build-enterprise-grade-ai-agents-agentic-design-patterns](https://www.tungstenautomation.com/learn/blog/build-enterprise-grade-ai-agents-agentic-design-patterns)  
66. Multi-agent PRD automation with MetaGPT, Ollama, and DeepSeek | IBM, accessed March 23, 2026, [https://www.ibm.com/think/tutorials/multi-agent-prd-ai-automation-metagpt-ollama-deepseek](https://www.ibm.com/think/tutorials/multi-agent-prd-ai-automation-metagpt-ollama-deepseek)  
67. Agentic AI: The New Software Paradigm \- KI-Campus, accessed March 23, 2026, [https://ki-campus.org/en/blog/agentic-ai](https://ki-campus.org/en/blog/agentic-ai)  
68. Build 100% Local Planning Agent with Qwen and LangGraph | Private Financial AI Agent with Ollama \- YouTube, accessed March 23, 2026, [https://www.youtube.com/watch?v=ur504mUpp0o](https://www.youtube.com/watch?v=ur504mUpp0o)

[image1]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAFYAAAAYCAYAAABgBArrAAADFElEQVR4Xu2YS6hNURjHP+9IUUgGXhkYkUIKeeSVlBiIiRIyV5JQd2CiRGKm5DEwlzLAxDNEeRQGSIlM5JVH5PH971rrnHX/+1vn7Lv37lyde3717+z9/9Zae63vrLX32lukQ4cOIgvZaEMmqAaymYflqrH+eIDqiGqvakythM03ceX7A3/ZaMZ71Rl//Fn1R1wjQTt9jLmmWhydI8EfpWddtM38lnocx31B3MdmCgwVl5umjBZXcYY/x/HKeli2ey9uPDBVbB+cEhdbQn5Mqm4rGSSuH4854Dkk2X7eUh0mLwMqrfPHL8W+QJi948n/oFpPXmCLuDr7yA+cV81msxfcZKMgu8T1MzWOYapH5IU/I8k7ccsWzBRX2LpX4haB2AbyGzU+TVz8IgeUEaq3bPaS22wU5JNkxzFZ3GoEeFgdj2IB1MEzKcMUccFR/vyCamIt2hPcX1F2fuRt9V4jEEfHmZ9sFOAeGwVBH3kcd6NjJDbkKOaZ9CxXw/qnUlySbFk0+oY8xur0NtV+8opwn40ChCX9SjVPtUJ10nvNwG7JLGcNOkW4x7J3nTzGugafF6WKxO4W15+zqoOqE/4cz5pmbJLEWGDm2jaIK9tleGF7loIT+0Q1LjrPw3DVHENPDS8oL18km5yNqs3R+aLoOAYznOt2w4NOgWVrlYN3mk3iu9Tr4mF2I4rlBdvBtYaeG15QXqwcYBbHpJ4HcyVbtxurUWaIuDLhbSzmh+oqm8QVcfUn+d8qKXsrCGO7w4EI3B5SMxYz2xzTC3EB/PMW4cILOOB5qHrNJtElrg2UW02xspRNbFiJazjgwZbQTJxnjyTi2EaEWYslO9372BCf8/5I71nskETDEUvFlcGLRNWUTSxWnNV/7BQOiIsdpVgMXqQesBnAe+8vqSc4aFlcqAFWx2IGiytjvXSUpWhi8R0E3yb4W0gQYsjJ11AhAcquYrMq0Dj2fn1B0cRWASZKs0lVilmSf8tWNYW+i1bEZdUxNqsG7/xIcH8Bf2jLPnO27EL/AS0fK3YA7Q5ecrBr6tChDfgH0mDbrMiA9TIAAAAASUVORK5CYII=>

[image2]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACkAAAAXCAYAAACWEGYrAAAB/ElEQVR4Xu2WPUgdQRSFrwG1UNSgYCUYGyuDtRFEEq21EFKLCCqGCDaGYKp0IthpFxFiIdrYpYs2IqSQNBZq4w+KSFTwByXGe5gZ377zZp1RfGCRDw6O3707O8wOu0/kP8+bZhYB3rOI5Z2myo4LNOOaT5rKuw4/52L6H0KdZo1liCPNtB2fam40/xIZsjVmSdPCMsGwpo+lZUIzxdJHhZhFNNj/MW7PlKXHOoR5JX4/q7mSzHX92eUsfNfngKYOO97S/E7UHG5Xq8n/0XSSY0KLnJHAY9/XHNvxazET+s4WjgFqXeRjdiG0yHK5Z55aMUU0gUVNzV01G5xH9DYlXLd1IUKLBOgpYwlOJO4m4Ifk9q5qdsn5iF3kCEuAAt84DXcm2S2T84HrBlgS6HFvlixQwI1iQO8Xj/NOTKBvkCVxoVlhCWJ38rP4++C+sfSAvg8siTPNL5YgZpGFYnrcVyjJpeYnSw+4/iNLAj0LLMGmmOIGFyxugW+4YMG7bZulB8yR9rVyoAef3xxeSGY3cSbqrS/WfLe+1DofvRJ+EngC6BnjAoGelywdRZprySzW5W2y6R7SFjmnOdTsiNlt/D0Q86lkSiR9nicBk7exfCCTmnmWT0mjxL/G0sjrLjr2xCz2MYxqvrLMF39ZRIBfVOss800riwChF/zz5xYyH4Pf9xggWAAAAABJRU5ErkJggg==>

[image3]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABMAAAAXCAYAAADpwXTaAAAAVUlEQVR4XmNgGAWjgKpgL7oAJeAfugAlwAaIy9AFKQHngNgcXRAETMjEt4B4HwMa8CMTX4NiFgYKwUQg9kYXJAcoAnEnuiC54BO6ACXgMLrAKBhuAACnlhESw2iRqwAAAABJRU5ErkJggg==>