# **Comprehensive Architectural Audit and Optimization Strategy for High-Performance Metal Graph Visualization**

## **1\. Introduction and Diagnostic Overview**

The development of high-performance graph visualization engines on macOS requires a delicate orchestration of high-level declarative interfaces, low-level graphics APIs, and systems-level memory management. The application under audit operates on a highly sophisticated hybrid architecture, utilizing Swift for the application lifecycle and data modeling, Apple's Metal framework for hardware-accelerated rendering, and a Rust core integrated via a Foreign Function Interface (FFI) for heavy computational logic. While this tri-partite architecture offers the potential for immense computational throughput, it introduces complex synchronization and compilation boundaries that must be meticulously managed.

The primary diagnostic symptom reported is a severe, temporary freeze of the main thread that occurs exclusively during the first instantiation of the graph visualization view, particularly when loading topologies exceeding 10,000 nodes. Secondary symptoms include visual glitches, such as flickering during graph updates, and generalized main-thread saturation. The development team has recently implemented a "Phase 2" optimization strategy featuring an atomic swap pattern, background Breadth-First Search (BFS) topology calculations, and detached task offloading.

This exhaustive audit evaluates the entirety of this implementation. The analysis indicates that the initial rendering freeze is a classic manifestation of Just-In-Time (JIT) Metal shader compilation and Pipeline State Object (PSO) initialization.1 Furthermore, the audit reveals that the secondary glitches and update latencies are not artifacts of the rendering engine itself, but rather systemic vulnerabilities introduced by the use of unstructured Swift concurrency (Task.detached), synchronous FFI memory marshalling on the @MainActor, and a pseudo-atomic buffering strategy that fails under specific edge conditions.3 This report provides a detailed, component-by-component architectural teardown, paired with actionable optimization strategies designed to eliminate initialization latency, enforce strict thread safety, and maximize cache locality across the language boundaries.

## **2\. The Mechanics of Just-In-Time Shader Compilation Latency**

To permanently resolve the severe lag experienced during the first opening of the graph view, it is imperative to understand the lifecycle of the Metal Shading Language (MSL) and the behavior of the MTLCompilerService. Unlike interpreted languages or simple application binaries, GPU shaders undergo a multi-stage compilation process that spans both the build time on the developer's machine and the run time on the end-user's device.

During the application build process in Xcode, Metal shaders are compiled into Apple Intermediate Representation (AIR).5 This AIR is hardware-agnostic, allowing the application binary to be distributed across a wide variety of Apple Silicon and legacy Intel architectures. However, the GPU cannot execute AIR directly. The final translation from AIR to device-specific GPU machine code occurs at runtime, precisely at the moment the application invokes the makeRenderPipelineState(descriptor:) method on the MTLDevice.2

When the user navigates to the graph view for the first time, the application must construct the rendering pipeline. This requires the MTLCompilerService to parse the AIR, apply link-time optimizations, evaluate function constants, and generate the final machine code.8 For a complex graph visualization engine utilizing specialized fragment shaders, anti-aliasing, and dynamic properties like the dialogueDepthColor palette, this compilation is highly CPU-intensive. Because the default pipeline creation methods are synchronous, the calling thread—inevitably the @MainActor responsible for the UI—is completely blocked until the compilation finishes.1 This results in a total application freeze that can last anywhere from tens of milliseconds to over a full second, depending on the complexity of the shaders and the thermal state of the device.1

Once the compilation succeeds, the Metal framework aggressively caches the resulting machine code in a hidden filesystem directory.1 Consequently, if the user closes the graph view and reopens it, the makeRenderPipelineState call simply retrieves the cached binary from disk, bypassing the compilation phase entirely. This mechanism perfectly explains why the latency is isolated exclusively to the first launch of the view and never occurs on subsequent accesses.

To eradicate this main-thread freeze without compromising rendering performance, the application must preempt the JIT compilation phase using one of two specific architectural strategies: offline compilation via binary archives, or asynchronous runtime pre-warming.

## **3\. Eradicating Latency via MTLBinaryArchive Serialization**

The most robust and performant solution to eliminate first-frame shader compilation stutter is the implementation of MTLBinaryArchive.7 Introduced to grant developers explicit control over pipeline state caching, a binary archive is a serialized collection of device-specific GPU binaries that can be bundled directly into the application's resources.11 By providing the Metal runtime with a pre-populated archive, the system can bypass the CPU-intensive AIR-to-machine-code translation entirely, reducing pipeline creation time from hundreds of milliseconds to mere microseconds.6

## **Implementation Phase 1: Archiving During Development**

The implementation of this strategy begins in the development environment. The application must be configured to run in a special profiling mode designed to capture and serialize the pipeline states as they are naturally generated by the graph engine.7

The application initializes an empty MTLBinaryArchive using an MTLBinaryArchiveDescriptor.7 As the graph view is opened and the application constructs its MTLRenderPipelineDescriptor instances, these descriptors are injected into the archive using the addRenderPipelineFunctions(descriptor:) method.11 It is critical that this profiling run exercises all possible permutations of the graph's rendering logic, including different node types, edge weights, and color palettes, to ensure that every necessary shader variant is captured.

Once the application has rendered the complete graph, the populated archive is serialized to the local disk using the serialize(to:) method, producing a .metallib file containing the finalized machine code.12 For applications targeting multiple GPU architectures, Apple provides command-line tools to stitch together binary archives from different devices into a single, universal archive.13

## **Implementation Phase 2: Loading During Production**

The serialized .metallib file is then added to the Xcode project's "Copy Bundle Resources" build phase, ensuring it is distributed alongside the application binary.7

In the production environment, the application initialization sequence is modified to utilize this archive. When constructing the MTLRenderPipelineDescriptor for the graph view, the application first instantiates the bundled MTLBinaryArchive via the makeBinaryArchive(descriptor:) method. This archive instance is then assigned to the binaryArchives property of the pipeline descriptor.7 When makeRenderPipelineState is subsequently invoked, the Metal framework detects the attached archive, locates the pre-compiled binary, and instantly loads it into the GPU, completely circumventing the compilation freeze.2

| Pipeline Creation Strategy | Main Thread Block Time | CPU Utilization | Implementation Complexity |
| :---- | :---- | :---- | :---- |
| **Synchronous JIT Compilation** | 100ms – 500ms | Extreme (Translation and Optimization) | Low (Default Framework Behavior) |
| **MTLBinaryArchive Retrieval** | \< 5ms | Negligible (Direct Memory Access) | High (Requires Profiling and Serialization) |

If the graph visualization relies on highly dynamic shader permutations that cannot be reliably captured during a profiling run, or if the distribution of a massive universal binary archive is unfeasible due to application size constraints, an alternative pre-warming strategy must be employed.

## **4\. Asynchronous Pipeline Pre-warming**

When binary archiving is not viable, the application must shift the burden of JIT compilation off the @MainActor. The Metal framework provides an asynchronous counterpart to pipeline creation: the makeRenderPipelineState(descriptor:completionHandler:) method, or its modern Swift Concurrency equivalent, makeRenderPipelineState(descriptor:) async throws.14

To prevent the user from experiencing a freeze when opening the graph, the application must anticipate the need for the graph shaders long before the view is actually instantiated. This is achieved through a background pre-warming initialization sequence. When the application launches, or when the user navigates to a section of the application where the graph view might logically be accessed next, a detached background task is spawned. This task constructs the necessary MTLRenderPipelineDescriptor objects and invokes the asynchronous creation methods.17

Because these methods are asynchronous, the MTLCompilerService performs the heavy AIR-to-machine-code translation on a background thread managed by the Metal framework.14 The @MainActor remains entirely unblocked, ensuring that the application UI remains fluid and responsive to user input. The resulting pipeline states are either cached automatically by the OS or explicitly retained in a singleton configuration object. By the time the user actually taps the button to open the MetalGraphView, the compilation has already finished in the background, and the view can initialize instantly using the pre-warmed pipeline states. If the user opens the view before the background compilation has finished, the application can display a lightweight, non-blocking loading indicator, which provides a vastly superior user experience compared to a total application freeze.19

## **5\. Swift Concurrency and the Task.detached Anti-Pattern**

Beyond the initial shader compilation latency, the audit must address the secondary symptoms: the flickering during graph updates and the systemic risks introduced by the "Phase 2" optimization strategy. The current implementation captures a GraphStoreSnapshot on the @MainActor, offloads the ![][image1] FFI payload construction to a Task.detached, and utilizes a MainActor.run block to clear the engine, send the batches, and commit the data.

While the intent behind this pattern—moving heavy computational work off the UI thread—is structurally sound, the specific utilization of Task.detached violates the principles of structured concurrency and introduces severe lifecycle and race condition vulnerabilities.

## **The Mechanics of Unstructured Execution**

In the Swift concurrency model, a standard Task inherits the execution context of its creator. If a Task is spawned from within a method isolated to the @MainActor, the new task inherently executes on the main actor's cooperative thread pool, unless the work is explicitly delegated to a non-isolated function.20 To bypass this inheritance and force work onto a global background executor, developers often reach for Task.detached.21

However, Task.detached creates an unstructured task that is completely divorced from its origin. It does not inherit the actor context, it does not inherit task-local values, and most critically, it does not inherit task priority or cancellation propagation.21 This detachment is the root cause of the stability risks within the graph visualization app.

## **The View Deallocation Vulnerability**

The first major risk introduced by the Task.detached pattern involves the lifecycle of the MetalGraphView. Suppose the user initiates an update that requires formatting 20,000 nodes for the Rust engine. The application captures the snapshot and spawns the detached task. If the user immediately navigates away from the view, the application will deallocate the MetalGraphView and its associated view controllers.23

Because the task is detached, the deallocation of the view does not automatically cancel the task. The Swift runtime will continue executing the heavy ![][image1] payload construction in the background, needlessly consuming CPU cycles, memory bandwidth, and battery life for a view that no longer exists.23 Furthermore, once the payload is constructed, the detached task will invoke its MainActor.run block. If this block captures strong references to the view or the Rust engine pointer, it creates a retain cycle that prevents memory from being freed.24 If it does not capture a strong reference, it may attempt to call the graph\_engine\_clear or sendBatches FFI functions using a stale or null pointer, resulting in a catastrophic EXC\_BAD\_ACCESS memory violation and an immediate application crash.

To mitigate this, the closure must utilize a \[weak self\] capture list, and the execution must verify the continued existence of the view before interacting with the FFI layer.25 However, relying on weak references merely prevents the crash; it does not stop the wasted background computation.

## **Overlapping Commits and Race Conditions**

The second, more insidious risk involves the management of overlapping updates. The current implementation attempts to manage races by maintaining a currentCommitTask: Task\<Void, Never\>? property, which is explicitly cancelled at the beginning of every commitGraphData() invocation.

The flaw in this logic is that calling .cancel() on a Swift Task does not forcefully terminate the underlying thread.21 Swift concurrency relies on cooperative cancellation. When .cancel() is invoked, it merely flips a boolean flag on the task's internal state.22 If the code executing within the detached task does not explicitly check this flag by calling Task.checkCancellation() or try Task.checkCancellation(), the task will continue running to completion exactly as if it had never been cancelled.22

Consider a scenario where the user rapidly triggers two distinct graph updates.

1. Update A is fired, generating Detached Task A.  
2. Update B is fired immediately after. The code cancels currentCommitTask (Task A) and generates Detached Task B.  
3. Because Task A lacks cooperative cancellation checks, it continues processing.  
4. Due to the unpredictable nature of operating system thread scheduling, Task B might finish its payload construction slightly faster than Task A.  
5. Task B queues its MainActor.run block, clearing the engine and committing the new data.  
6. Milliseconds later, Task A finally finishes. It queues its own MainActor.run block, clearing the engine and committing the *older, outdated* data.

This race condition perfectly explains the flickering and glitching observed during graph updates.28 The rendering engine is receiving overlapping, out-of-order state mutations because the detached tasks are executing unpredictably and forcing their results onto the main thread without structural synchronization.

## **6\. Restoring Structured Concurrency and Cooperative Cancellation**

To resolve the view deallocation risks and the overlapping commit races, the application must abandon Task.detached and return to the safety of structured concurrency. This is achieved by utilizing standard Task blocks in conjunction with non-isolated background functions.30

By spawning a standard Task from within the @MainActor context, the task remains structurally linked to the view's lifecycle. If the view utilizes SwiftUI's .task modifier, or if the view explicitly cancels its retained tasks during its deinit phase, the cancellation signal cascades correctly.27 To ensure that the heavy ![][image1] payload construction does not block the main actor, the work itself must be encapsulated within a function marked with the nonisolated keyword, or explicitly assigned to a global executor using Swift 6's @concurrent attribute.32

| Concurrency Pattern | Priority Inheritance | Cancellation Propagation | Execution Context |
| :---- | :---- | :---- | :---- |
| Task.detached { } | None | Manual only | Global Executor |
| Task { } (Inside @MainActor) | Inherited | Automatic via Parent | @MainActor |
| Task { await nonisolatedFunc() } | Inherited | Automatic via Parent | Main Actor ![][image2] Global Executor |

Within the non-isolated payload construction function, the code must implement rigorous cooperative cancellation. The iteration over the 10,000+ nodes and edges must be punctuated by calls to try Task.checkCancellation(). If the user navigates away, or if a newer update supersedes the current one, the cancellation flag will be detected, a CancellationError will be thrown, and the heavy computation will be aborted instantly, freeing up CPU resources and completely preventing out-of-order MainActor.run execution.22

## **7\. FFI Boundary Optimization and Main Thread Starvation**

The most critical architectural bottleneck identified in the audit is the execution of the sendNodeBatch FFI calls from within the MainActor.run block after the background task has finished compiling the payload.3 This specific design choice guarantees main thread starvation and extreme frame dropping during graph updates.

## **The Overhead of Memory Marshalling**

A Foreign Function Interface (FFI) allows Swift code to invoke functions written in Rust, and vice versa. While a single FFI function call is relatively inexpensive—often executing in a matter of microseconds or nanoseconds—the overhead accumulates rapidly when transferring complex data structures across the language boundary.36

Swift and Rust utilize fundamentally different memory allocators and layout semantics. When data is passed from Swift to Rust, it must often be marshalled, ensuring that the target language can safely interpret the pointers and memory strides.38 If the application utilizes a sendBatches() approach, iteratively calling an FFI function hundreds or thousands of times to push individual nodes or small groups of nodes into the Rust engine, the context-switching and marshalling overhead becomes immense.37

If the process of transferring 10,000 nodes via sendBatches takes 60 milliseconds, executing this loop inside a MainActor.run block means the main thread is completely paralyzed for 60 milliseconds.4 In a graphics application targeting 60 frames per second, the rendering engine has a strict budget of 16.67 milliseconds per frame. A 60-millisecond stall guarantees that multiple frames will be dropped, causing the UI to lock up, animations to hitch, and the overall experience to degrade significantly.23 Swift Concurrency strictly dictates that the main thread cannot interleave other rendering or UI tasks while a synchronous function (such as a blocking FFI loop) is executing on the actor.42

## **Achieving ![][image3] Time Complexity via Contiguous Memory**

To eliminate main thread starvation, the FFI data transfer must be optimized to operate in ![][image3] time relative to the @MainActor. It is fundamentally unsafe for performance to execute ![][image1] iterative loops across language boundaries on a UI thread.43

The solution is to abandon the iterative batching approach in favor of a zero-copy, contiguous memory transfer.44 The background Swift task, operating via the non-isolated function, should allocate a single, flat memory buffer—such as an UnsafeMutableBufferPointer—containing C-compatible structures representing the node and edge data. These structures must be explicitly marked with \#\[repr(C)\] in the Rust source code to guarantee that the memory layout matches the C Application Binary Interface (ABI), which Swift can natively interpret.39

1. **Background Processing:** The non-isolated Swift task iterates over the GraphStoreSnapshot and populates the UnsafeMutableBufferPointer with the precise float and integer values required by the graphics engine. All data formatting and calculation occur on the background thread.  
2. **The FFI Pointer Transfer:** Once the buffer is complete, a single FFI function is invoked, passing only the raw memory pointer and the length of the buffer.  
3. **Main Thread Execution:** Because passing a pointer takes only nanoseconds, executing this single FFI call within the MainActor.run block blocks the main thread for less than a single millisecond. The UI remains entirely responsive, and the frame rate is preserved.40

If the Rust engine requires complex internal processing or tree-building upon receiving the data, that processing must also occur asynchronously. The Rust FFI functions do not inherently require execution on the main thread unless they are directly interacting with Apple's UI frameworks (such as AppKit or UIKit), which is an anti-pattern for a core rendering engine.46 Therefore, the ideal architecture delegates the entire pointer transfer and internal Rust processing to the background thread, invoking the main thread exclusively for the final rendering commit.

## **8\. Transactional Engine Resilience and True Atomic Swaps**

The implementation details note that the application attempts an "Atomic Swap" pattern using the following synchronous sequence inside the MainActor.run block:

graph\_engine\_clear(engine); sendBatches(); graph\_engine\_commit(engine);

The audit explicitly questions what occurs if graph\_engine\_clear is executed, but the subsequent sendBatches fails or is cancelled.

## **The Catastrophic "Blank Screen" Anomaly**

The sequence provided is not a true atomic swap; it is a sequential, destructive mutation of the live rendering state. An operation is only "atomic" if it succeeds entirely or fails entirely, ensuring that the consumer of the data never witnesses a partially completed state.48

In the current implementation, graph\_engine\_clear instantly purges the live topology from the rendering engine. If the subsequent sendBatches encounters a memory allocation failure, an FFI marshalling error, or a cooperative cancellation event, the sequence aborts before graph\_engine\_commit can be called. The live visualization view is left in a corrupted, empty state, rendering a completely blank screen to the user. This destroys the continuity of the user experience and leaves the application in an unrecoverable visual state.

## **Architecting a Deterministic Double-Buffered Engine**

To achieve a resilient, true atomic swap, the underlying Rust graphics engine must be refactored to support a double-buffered data architecture. Instead of mutating the live data structures currently being accessed by the rendering loops, the system must build the new state entirely in isolation.48

1. **Offline Buffer Creation:** The background Swift task instructs the Rust engine via FFI to allocate a completely new, offline memory buffer (graph\_engine\_create\_offline\_buffer()). This buffer is entirely invisible to the active Metal rendering pipeline.  
2. **Asynchronous Population:** The non-isolated task populates this offline buffer using the contiguous memory pointer transfer described in Section 7\. If this operation fails, or if a cancellation flag is detected, the offline buffer is simply discarded. Because the live data was never touched, the graph view continues rendering the previous frame flawlessly.  
3. **The Atomic Pointer Swap:** If the offline buffer is successfully populated, the background task transitions to the MainActor.run block. Inside this block, a single, deterministic FFI command is executed: graph\_engine\_swap\_buffers(engine, new\_buffer\_id).

This swap command does not move data; it merely updates a high-level reference pointer within the Rust engine to point to the new data structures, and schedules the old structures for deallocation.50 This pointer swap is an atomic, ![][image3] CPU instruction that executes in nanoseconds. It guarantees absolute resilience against data formatting errors and completely insulates the user interface from mid-update cancellations.

## **Camera Centering Considerations**

The audit notes that graph\_engine\_center\_camera(engine) is appended to the end of the MainActor.run block when entrance \== 1\.

Executing a camera interpolation immediately following a destructive clear and sendBatches loop is highly problematic. Because the main thread's 16.67ms frame budget was likely exhausted by the synchronous data transfer, the renderer will miss the first several V-Sync intervals of the camera's panning animation. This results in the camera appearing to "snap" or jump jarringly to the center, rather than executing a smooth, continuous glide.51

By implementing the double-buffered atomic pointer swap, the main thread is relieved of all data marshalling burdens. When graph\_engine\_center\_camera is subsequently invoked, the CPU has ample headroom to calculate the interpolation matrices, ensuring that the camera animation plays back at a pristine 60 or 120 frames per second.

## **9\. Topology Isolation and the W7.4 Compact Adjacency Architecture**

A critical component of the audit involves verifying that the non-isolated methods operating on the GraphStoreSnapshot are truly thread-safe and immune to actor contention. This verification requires a deep dive into the memory architecture of the GraphStore and its W7.4 Compact Adjacency Storage implementation.

## **The Memory Economics of Compact Adjacency**

In graph theory applications, the naive approach to storing adjacency (the list of edges connecting nodes) relies on dictionaries mapped to sets of strings, such as \`\`. While this provides an intuitive, highly readable API, it is catastrophic for memory performance at scale. A Set\<String\> requires significant heap allocation overhead, storing pointer references, string encodings, and hash table metadata. For a single node, this can easily consume upwards of 100 bytes.52

The application brilliantly circumvents this overhead through the W7.4 specification. The GraphStore replaces the traditional dictionary with an internal mapping system. Unique string IDs are mapped to stable, compact integer indices (\_nodeIdx and \_edgeIdx). The adjacency list itself is stored as a tightly packed array of integer arrays: \[\[Int\]\].

By replacing 100-byte string sets with 8-byte integers, the memory footprint drops precipitously. The audit confirms that for a graph containing 50,000 nodes with an average degree of 5, the W7.4 architecture reduces adjacency memory consumption from roughly 25MB to a mere 2MB—a savings of 46MB.52 To ensure that the rest of the application (comprising over 20 consumer sites) is not broken by this internal refactor, the GraphStore utilizes proxy structs, such as AdjacencyProxy, which intercept subscript requests (store.adjacency\[nodeId\]) and dynamically generate the expected Set\<String\> on the fly by mapping the compact integers back to their original string identifiers.

| Storage Architecture | Memory per Reference | Total Size (50k Nodes, Degree 5\) | CPU Cache Locality |
| :---- | :---- | :---- | :---- |
| \`\` | \~100 bytes | \~25 MB | Extremely Poor (Heap Fragmentation) |
| W7.4 \[\[Int\]\] Compact Index | 8 bytes | \~2 MB | Excellent (Contiguous Memory) |

## **Thread Safety and the Sendable Protocol**

The transition to \[\[Int\]\] adjacency arrays has profound implications for the thread safety of the GraphStoreSnapshot. Swift relies heavily on value semantics for its standard library collections. Arrays and integers are primitive value types. When the GraphStore generates a GraphStoreSnapshot on the main actor, the \[\[Int\]\] arrays are copied. Thanks to Swift's copy-on-write (COW) optimization, this copy operation is practically instantaneous; the underlying memory is only duplicated if the original GraphStore is mutated while the snapshot is held.

Because the snapshot relies entirely on immutable value types rather than reference-type classes, the GraphStoreSnapshot struct implicitly conforms to the Sendable protocol.53 The Sendable protocol is Swift Concurrency's mechanism for guaranteeing that a type is safe to share across concurrent domains. Passing the snapshot from the @MainActor to the non-isolated background task cannot, by definition, cause a data race. The background task possesses a mathematically pristine, isolated copy of the graph topology at a specific point in time, entirely immune to subsequent mutations occurring on the main thread.26

Furthermore, the use of compact \[\[Int\]\] arrays dramatically accelerates the background Breadth-First Search (BFS) required for the folder-depth calculations. Modern CPUs rely on hierarchical cache systems (L1, L2, L3) to feed data to the execution pipelines. Iterating over scattered heap-allocated Set\<String\> objects causes constant cache misses, forcing the CPU to retrieve data from slow main memory (RAM). Conversely, iterating over a dense, contiguous array of integers allows the CPU's prefetcher to load the entire array into the ultra-fast L1 cache, allowing the BFS algorithm to execute with devastating speed.40 The W7.4 architecture is perfectly suited for background topological analysis.

## **10\. Disk I/O Elimination via Persistent Block Caching**

The final component of the background topology calculation involves the generation of nodes and edges based on the application's underlying data models. The application relies on SwiftData entities, specifically the SDPage model, to represent individual notes or documents.

In a hybrid persistence system, the metadata (such as titles, creation dates, and folder hierarchies) is stored in a structured SQLite database via SwiftData, while the actual heavy content of the document is written to a raw markdown file (.md) on the filesystem. When the GraphBuilder attempts to construct the structural graph, it must resolve block references—links from one note to a specific paragraph in another note, formatted using the ((blockId)) syntax.52

If the system had to open, read, and parse every single .md file on disk to locate these block references during the graph initialization sequence, it would incur an ![][image1] disk I/O penalty. Disk operations are orders of magnitude slower than memory access. Attempting to parse 10,000 text files would cause the graph builder to hang for several seconds, completely stalling the background task and delaying the rendering pipeline.

The application successfully circumvents this bottleneck through the implementation of a persistent block reference cache directly on the SDPage model.52

## **The saveBody Extraction Mechanism**

Within the SDPage.swift implementation, the application relies on a strictly controlled saveBody(\_:) method to handle content updates. When new text is saved, the method performs the standard disk write via NoteFileStorage.writeBody. Crucially, it simultaneously executes a Swift Regex pattern—/\\(\\((\[^)\]+)\\)\\)/—against the text string to dynamically extract all block reference IDs.52

These extracted IDs are sanitized via compactMap to remove whitespace and invalid characters, and are then appended to the blockReferences: property.52 Because blockReferences is a standard, managed SwiftData property, these references are stored directly in the high-speed SQLite database alongside the note's metadata.

When the background task invokes the GraphBuilder, the builder queries SwiftData for the blockReferences array directly. The graph engine can instantly resolve the topological connections between notes without ever touching the filesystem, dropping the topological construction time from seconds to milliseconds.52

## **Background Fetching and Isolation Nuances**

While the persistent cache effectively solves the disk I/O problem, the audit notes that accessing SwiftData models on a background thread introduces its own set of strict concurrency challenges. SwiftData's ModelContext is fundamentally tied to the actor on which it was created. If a background task attempts to lazily evaluate relationships or access properties of an SDPage instance that was fetched on the @MainActor, the Swift 6 compiler will flag severe isolation violations, and the application will likely deadlock or crash at runtime.55

To maintain the integrity of the background BFS, the GraphBuilder must operate exclusively using an isolated ModelActor operating on a custom background executor, or it must map the necessary SwiftData properties into raw, Sendable value types (such as primitive structs) before passing them across the actor boundary.57 The deterministic snapshot design of the GraphStore achieves exactly this, divorcing the topological logic from the underlying database models before parallelizing the workload, guaranteeing absolute thread safety across the entire visualization pipeline.

## **11\. Conclusion and Executive Recommendations**

The application's architecture is a highly sophisticated integration of Metal rendering, Swift data management, and Rust computational logic. The underlying data structures, specifically the W7.4 Compact Adjacency Storage and the SDPage persistent block reference cache, are masterfully engineered for maximum memory efficiency, cache locality, and algorithmic throughput.

However, the severe latency and rendering glitches reported are the direct consequence of synchronization failures at the boundaries of these systems. To achieve a zero-latency, stutter-free visualization engine capable of rendering massive topologies instantly, the following structural mandates must be adopted:

1. **Eliminate JIT Compilation Latency:** The initial freeze is entirely attributable to the synchronous compilation of Metal Pipeline State Objects. The application must implement MTLBinaryArchive to capture and serialize the shader descriptors during development, bundling the resulting .metallib archive with the application. If dynamic permutations require runtime compilation, the makeRenderPipelineState calls must be executed asynchronously in a pre-warming task long before the graph view is opened.  
2. **Restore Structured Concurrency:** The reliance on Task.detached must be eradicated. Unstructured tasks do not inherit cancellation and will outlive deallocated views, leading to memory corruption and out-of-order execution races. Replace this pattern with standard Task blocks invoking nonisolated functions, and implement rigorous try Task.checkCancellation() checks during heavy iteration loops.  
3. **Optimize FFI Marshalling:** Executing ![][image1] sendBatches() loops inside MainActor.run causes catastrophic main thread starvation and frame dropping. The background task must serialize the topology into a contiguous UnsafeMutableBufferPointer of C-compatible structs. A single, ![][image3] FFI pointer transfer is all that is required, reducing main thread blocking from tens of milliseconds to nanoseconds.  
4. **Implement Deterministic Double-Buffering:** The current sequential clear-send-commit pattern is pseudo-atomic and vulnerable to catastrophic failure. The Rust engine must be refactored to support offline buffer construction. The background task populates the offline buffer entirely invisible to the renderer. Once complete, the MainActor executes a singular, atomic pointer swap, guaranteeing that the user interface is completely insulated from intermediate states, formatting errors, and cancellation events.

#### **Works cited**

1. Apple Metal shader compilation time? : r/GraphicsProgramming \- Reddit, accessed March 22, 2026, [https://www.reddit.com/r/GraphicsProgramming/comments/1g588j8/apple\_metal\_shader\_compilation\_time/](https://www.reddit.com/r/GraphicsProgramming/comments/1g588j8/apple_metal_shader_compilation_time/)  
2. Metal binary archives | Apple Developer Documentation, accessed March 22, 2026, [https://developer.apple.com/documentation/metal/metal-binary-archives?changes=la](https://developer.apple.com/documentation/metal/metal-binary-archives?changes=la)  
3. Why Task under MainActor can hurts performance \- // by kei\_sidorov, accessed March 22, 2026, [https://sidorov.tech/en/all/why-task-under-mainactor-hurts-performance/](https://sidorov.tech/en/all/why-task-under-mainactor-hurts-performance/)  
4. Analyzing the performance of your Metal app | Apple Developer Documentation, accessed March 22, 2026, [https://developer.apple.com/documentation/xcode/analyzing-the-performance-of-your-metal-app/](https://developer.apple.com/documentation/xcode/analyzing-the-performance-of-your-metal-app/)  
5. Target and optimize GPU binaries with Metal 3 | Documentation \- WWDC Notes, accessed March 22, 2026, [https://wwdcnotes.com/documentation/wwdcnotes/wwdc22-10102-target-and-optimize-gpu-binaries-with-metal-3/](https://wwdcnotes.com/documentation/wwdcnotes/wwdc22-10102-target-and-optimize-gpu-binaries-with-metal-3/)  
6. Build GPU binaries with Metal | Documentation \- WWDC Notes, accessed March 22, 2026, [https://wwdcnotes.com/documentation/wwdcnotes/wwdc20-10615-build-gpu-binaries-with-metal/](https://wwdcnotes.com/documentation/wwdcnotes/wwdc20-10615-build-gpu-binaries-with-metal/)  
7. Creating binary archives from device-built pipeline state objects \- Apple Developer, accessed March 22, 2026, [https://developer.apple.com/documentation/metal/creating-binary-archives-from-device-built-pipeline-state-objects](https://developer.apple.com/documentation/metal/creating-binary-archives-from-device-built-pipeline-state-objects)  
8. First load extremely slow due to metal shader compliation (MTLCompilerService) · Issue \#106757 · godotengine/godot \- GitHub, accessed March 22, 2026, [https://github.com/godotengine/godot/issues/106757](https://github.com/godotengine/godot/issues/106757)  
9. Metal shader fails to compile on macOS 26.1 \- Stack Overflow, accessed March 22, 2026, [https://stackoverflow.com/questions/79840668/metal-shader-fails-to-compile-on-macos-26-1](https://stackoverflow.com/questions/79840668/metal-shader-fails-to-compile-on-macos-26-1)  
10. Minimizing Filament Startup Time on iOS by Precompiling Metal Shaders \#8940 \- GitHub, accessed March 22, 2026, [https://github.com/google/filament/discussions/8940](https://github.com/google/filament/discussions/8940)  
11. MTLBinaryArchive | Apple Developer Documentation, accessed March 22, 2026, [https://developer.apple.com/documentation/metal/mtlbinaryarchive](https://developer.apple.com/documentation/metal/mtlbinaryarchive)  
12. Compiling binary archives from a custom configuration script \- Apple Developer, accessed March 22, 2026, [https://developer.apple.com/documentation/metal/compiling-binary-archives-from-a-custom-configuration-script](https://developer.apple.com/documentation/metal/compiling-binary-archives-from-a-custom-configuration-script)  
13. Investigate wiring up Metal Binary Archives on iOS. · Issue \#60267 \- GitHub, accessed March 22, 2026, [https://github.com/flutter/flutter/issues/60267](https://github.com/flutter/flutter/issues/60267)  
14. Pipeline state creation | Apple Developer Documentation, accessed March 22, 2026, [https://developer.apple.com/documentation/metal/pipeline-state-creation](https://developer.apple.com/documentation/metal/pipeline-state-creation)  
15. makeRenderPipelineState(descriptor:completionHandler:) | Apple Developer Documentation, accessed March 22, 2026, [https://developer.apple.com/documentation/metal/mtldevice/makerenderpipelinestate(descriptor:completionhandler:)](https://developer.apple.com/documentation/metal/mtldevice/makerenderpipelinestate\(descriptor:completionhandler:\))  
16. makeRenderPipelineState(descriptor:options:completionHandler:) | Apple Developer Documentation, accessed March 22, 2026, [https://developer.apple.com/documentation/metal/mtldevice/makerenderpipelinestate(descriptor:options:completionhandler:)-1wvya?changes=\_7\_3\_8](https://developer.apple.com/documentation/metal/mtldevice/makerenderpipelinestate\(descriptor:options:completionhandler:\)-1wvya?changes=_7_3_8)  
17. Preparing your Metal app to run in the background | Apple Developer Documentation, accessed March 22, 2026, [https://developer.apple.com/documentation/metal/preparing-your-metal-app-to-run-in-the-background](https://developer.apple.com/documentation/metal/preparing-your-metal-app-to-run-in-the-background)  
18. Using the Metal 4 compilation API | Apple Developer Documentation, accessed March 22, 2026, [https://developer.apple.com/documentation/Metal/using-the-metal-4-compilation-api](https://developer.apple.com/documentation/Metal/using-the-metal-4-compilation-api)  
19. Async/Await: is it possible to start a Task on @MainActor synchronously? \- \#20 by lhunath, accessed March 22, 2026, [https://forums.swift.org/t/async-await-is-it-possible-to-start-a-task-on-mainactor-synchronously/52862/20](https://forums.swift.org/t/async-await-is-it-possible-to-start-a-task-on-mainactor-synchronously/52862/20)  
20. Swift Concurrency in a Nutshell \- Bedrock Tech Blog, accessed March 22, 2026, [https://tech.bedrockstreaming.com/2023/11/14/swift-concurrency-in-a-nutshell.html](https://tech.bedrockstreaming.com/2023/11/14/swift-concurrency-in-a-nutshell.html)  
21. Detached Tasks in Swift explained with code examples \- SwiftLee, accessed March 22, 2026, [https://www.avanderlee.com/concurrency/detached-tasks/](https://www.avanderlee.com/concurrency/detached-tasks/)  
22. Detached Task \- Using Swift \- Swift Forums, accessed March 22, 2026, [https://forums.swift.org/t/detached-task/80810](https://forums.swift.org/t/detached-task/80810)  
23. Common Swift-Concurrency mistakes that can be killing your app performance | by Lucas Mrowskovsky Paim | Medium, accessed March 22, 2026, [https://medium.com/@lucasmrowskovskypaim/common-swift-concurrency-mistakes-that-can-be-killing-your-app-performance-b180a7ede4df](https://medium.com/@lucasmrowskovskypaim/common-swift-concurrency-mistakes-that-can-be-killing-your-app-performance-b180a7ede4df)  
24. Swift Concurrency: Task, Task.detached, Memory Management, Cancellation, and Edge Cases | by Akanksha Singh | Mar, 2026 | Medium, accessed March 22, 2026, [https://medium.com/@aksingh20feb/swift-concurrency-deep-dive-task-task-detached-memory-management-cancellation-and-edge-cases-baec260c0171](https://medium.com/@aksingh20feb/swift-concurrency-deep-dive-task-task-detached-memory-management-cancellation-and-edge-cases-baec260c0171)  
25. Why \`Task()\` and Various Other Questions \- Using Swift, accessed March 22, 2026, [https://forums.swift.org/t/why-task-and-various-other-questions/75273](https://forums.swift.org/t/why-task-and-various-other-questions/75273)  
26. Concurrency: async, await, Task, actor and @MainActor | by Ritika Verma \- Medium, accessed March 22, 2026, [https://medium.com/@ritika\_verma/concurrency-async-await-task-actor-and-mainactor-824f8838bb2c](https://medium.com/@ritika_verma/concurrency-async-await-task-actor-and-mainactor-824f8838bb2c)  
27. SwiftUI Async & Concurrency Patterns \- DEV Community, accessed March 22, 2026, [https://dev.to/sebastienlato/swiftui-async-concurrency-patterns-5e9j](https://dev.to/sebastienlato/swiftui-async-concurrency-patterns-5e9j)  
28. How do actors know how not to deadlock? \- Swift Forums, accessed March 22, 2026, [https://forums.swift.org/t/how-do-actors-know-how-not-to-deadlock/67265](https://forums.swift.org/t/how-do-actors-know-how-not-to-deadlock/67265)  
29. Make tasks in Swift concurrency run serially \- Stack Overflow, accessed March 22, 2026, [https://stackoverflow.com/questions/73026499/make-tasks-in-swift-concurrency-run-serially](https://stackoverflow.com/questions/73026499/make-tasks-in-swift-concurrency-run-serially)  
30. Is @concurrent now the standard tool for shifting expensive synchronous work off the main actor? \- Swift Forums, accessed March 22, 2026, [https://forums.swift.org/t/is-concurrent-now-the-standard-tool-for-shifting-expensive-synchronous-work-off-the-main-actor/82976](https://forums.swift.org/t/is-concurrent-now-the-standard-tool-for-shifting-expensive-synchronous-work-off-the-main-actor/82976)  
31. Rewriting my app to SwiftUI & Swift 6 (+ default actor isolation \== MainActor) \- How to off-load initial complex data loading to Task.detached & parallelising it? : r/swift \- Reddit, accessed March 22, 2026, [https://www.reddit.com/r/swift/comments/1opuidk/rewriting\_my\_app\_to\_swiftui\_swift\_6\_default\_actor/](https://www.reddit.com/r/swift/comments/1opuidk/rewriting_my_app_to_swiftui_swift_6_default_actor/)  
32. Is Task.detached a good and correct way to offload heavy work from the UI thread to keep the UI smooth? \- Stack Overflow, accessed March 22, 2026, [https://stackoverflow.com/questions/79538558/is-task-detached-a-good-and-correct-way-to-offload-heavy-work-from-the-ui-thread](https://stackoverflow.com/questions/79538558/is-task-detached-a-good-and-correct-way-to-offload-heavy-work-from-the-ui-thread)  
33. Task and Task.detached \- Using Swift \- Swift Forums, accessed March 22, 2026, [https://forums.swift.org/t/task-and-task-detached/80861](https://forums.swift.org/t/task-and-task-detached/80861)  
34. Difference between starting a detached task and calling a nonisolated func in main actor, accessed March 22, 2026, [https://stackoverflow.com/questions/74226295/difference-between-starting-a-detached-task-and-calling-a-nonisolated-func-in-ma](https://stackoverflow.com/questions/74226295/difference-between-starting-a-detached-task-and-calling-a-nonisolated-func-in-ma)  
35. Optimize FFI Handle Disposal for Immediate Rust-Side Memory Release · Issue \#524 · livekit/python-sdks \- GitHub, accessed March 22, 2026, [https://github.com/livekit/python-sdks/issues/524](https://github.com/livekit/python-sdks/issues/524)  
36. Overhead of Calling Rust FFI from Java JNR/JNI \- Reddit, accessed March 22, 2026, [https://www.reddit.com/r/rust/comments/b0leg9/overhead\_of\_calling\_rust\_ffi\_from\_java\_jnrjni/](https://www.reddit.com/r/rust/comments/b0leg9/overhead_of_calling_rust_ffi_from_java_jnrjni/)  
37. Rust performance impact when using FFI to C \- help, accessed March 22, 2026, [https://users.rust-lang.org/t/rust-performance-impact-when-using-ffi-to-c/102151](https://users.rust-lang.org/t/rust-performance-impact-when-using-ffi-to-c/102151)  
38. wasm-and-ffi-performance-comparison-in-node/README.md at main \- GitHub, accessed March 22, 2026, [https://github.com/yujiosaka/wasm-and-ffi-performance-comparison-in-node/blob/main/README.md](https://github.com/yujiosaka/wasm-and-ffi-performance-comparison-in-node/blob/main/README.md)  
39. Building High-Performance iOS Financial Charts with Rust and SwiftUI | by David Cruz, accessed March 22, 2026, [https://davthecoder.medium.com/building-high-performance-ios-financial-charts-with-rust-and-swiftui-c09a4d4881b1](https://davthecoder.medium.com/building-high-performance-ios-financial-charts-with-rust-and-swiftui-c09a4d4881b1)  
40. YOUR FFI IS SLOW BECAUSE YOU'RE IGNORING CPU CACHE LINES: A DEEP DIVE INTO RUST FFI OPTIMIZATION | by Santo Shakil | Medium, accessed March 22, 2026, [https://medium.com/@santoshakil/your-ffi-is-slow-because-youre-ignoring-cpu-cache-lines-a-deep-dive-into-rust-ffi-optimization-31000b37e4fe](https://medium.com/@santoshakil/your-ffi-is-slow-because-youre-ignoring-cpu-cache-lines-a-deep-dive-into-rust-ffi-optimization-31000b37e4fe)  
41. \`Task\` blocks main thread when calling async function inside \- Stack Overflow, accessed March 22, 2026, [https://stackoverflow.com/questions/71837201/task-blocks-main-thread-when-calling-async-function-inside](https://stackoverflow.com/questions/71837201/task-blocks-main-thread-when-calling-async-function-inside)  
42. async/await: How do I run an async function within a @MainActor class on a background thread? \- Stack Overflow, accessed March 22, 2026, [https://stackoverflow.com/questions/76650710/async-await-how-do-i-run-an-async-function-within-a-mainactor-class-on-a-backg](https://stackoverflow.com/questions/76650710/async-await-how-do-i-run-an-async-function-within-a-mainactor-class-on-a-backg)  
43. UI elements freeze despite webworker \- javascript \- Stack Overflow, accessed March 22, 2026, [https://stackoverflow.com/questions/43740722/ui-elements-freeze-despite-webworker](https://stackoverflow.com/questions/43740722/ui-elements-freeze-despite-webworker)  
44. How to pass array from Rust to FFI and free the memory properly \- Stack Overflow, accessed March 22, 2026, [https://stackoverflow.com/questions/79803394/how-to-pass-array-from-rust-to-ffi-and-free-the-memory-properly](https://stackoverflow.com/questions/79803394/how-to-pass-array-from-rust-to-ffi-and-free-the-memory-properly)  
45. What is the fastest way to return large amount of data from Rust FFI library back to C\# caller?, accessed March 22, 2026, [https://www.reddit.com/r/rust/comments/3zhpj0/what\_is\_the\_fastest\_way\_to\_return\_large\_amount\_of/](https://www.reddit.com/r/rust/comments/3zhpj0/what_is_the_fastest_way_to_return_large_amount_of/)  
46. The problem of safe FFI bindings in Rust \- Reddit, accessed March 22, 2026, [https://www.reddit.com/r/rust/comments/iev7za/the\_problem\_of\_safe\_ffi\_bindings\_in\_rust/](https://www.reddit.com/r/rust/comments/iev7za/the_problem_of_safe_ffi_bindings_in_rust/)  
47. Thread-safely wrapping C FFI library with effective interior mutability \- Rust Users Forum, accessed March 22, 2026, [https://users.rust-lang.org/t/thread-safely-wrapping-c-ffi-library-with-effective-interior-mutability/58714](https://users.rust-lang.org/t/thread-safely-wrapping-c-ffi-library-with-effective-interior-mutability/58714)  
48. What is Atomic Swap? Guide to Cross-Chain Exchanges \- Artoon Solutions, accessed March 22, 2026, [https://artoonsolutions.com/glossary/atomic-swap/](https://artoonsolutions.com/glossary/atomic-swap/)  
49. How Operating Systems Work \- Khoury College of Computer Sciences, accessed March 22, 2026, [https://www.khoury.northeastern.edu/\~pjd/CS5600-text-240905.pdf](https://www.khoury.northeastern.edu/~pjd/CS5600-text-240905.pdf)  
50. Is this atomic pointer swap pattern safe? \- Stack Overflow, accessed March 22, 2026, [https://stackoverflow.com/questions/67273040/is-this-atomic-pointer-swap-pattern-safe](https://stackoverflow.com/questions/67273040/is-this-atomic-pointer-swap-pattern-safe)  
51. Graph visualization efficiency of popular web-based libraries \- PMC \- NIH, accessed March 22, 2026, [https://pmc.ncbi.nlm.nih.gov/articles/PMC12061801/](https://pmc.ncbi.nlm.nih.gov/articles/PMC12061801/)  
52. GraphStore.swift  
53. Question on Sendability (Swift 6 data race safety) and FFI interfaces, accessed March 22, 2026, [https://forums.swift.org/t/question-on-sendability-swift-6-data-race-safety-and-ffi-interfaces/76219](https://forums.swift.org/t/question-on-sendability-swift-6-data-race-safety-and-ffi-interfaces/76219)  
54. Performance degradation for high numbers of threads in Rust \- Stack Overflow, accessed March 22, 2026, [https://stackoverflow.com/questions/59338406/performance-degradation-for-high-numbers-of-threads-in-rust](https://stackoverflow.com/questions/59338406/performance-degradation-for-high-numbers-of-threads-in-rust)  
55. Need help optimizing SwiftData performance with large datasets \- ModelActor confusion : r/SwiftUI \- Reddit, accessed March 22, 2026, [https://www.reddit.com/r/SwiftUI/comments/1jy8zkq/need\_help\_optimizing\_swiftdata\_performance\_with/](https://www.reddit.com/r/SwiftUI/comments/1jy8zkq/need_help_optimizing_swiftdata_performance_with/)  
56. Use SwiftData like a boss \- Medium, accessed March 22, 2026, [https://medium.com/@samhastingsis/use-swiftdata-like-a-boss-92c05cba73bf](https://medium.com/@samhastingsis/use-swiftdata-like-a-boss-92c05cba73bf)  
57. Is it a bit weird that all SwiftData operations require you to be in the main thread? \- Reddit, accessed March 22, 2026, [https://www.reddit.com/r/SwiftUI/comments/1fpk5mn/is\_it\_a\_bit\_weird\_that\_all\_swiftdata\_operations/](https://www.reddit.com/r/SwiftUI/comments/1fpk5mn/is_it_a_bit_weird_that_all_swiftdata_operations/)

[image1]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADAAAAAYCAYAAAC8/X7cAAACQElEQVR4Xu2Wy6tOURjGH9c4okyYuHQGpjJzK0I5SiYylJOBMmEilz9BRgaK/0FJmcgIEybqJCWUgST3S+6X8D7Wu863vud7916Hs5V0fvX07f28l9231tprL2CK/4+takySVWr8DstNZ0ynTAskFrHfdEzNDvihRo2TSEV7/H6Z6anp03jGIEtNj9QseI7UM0u5j/74nSI2bHpV3DcyHan4igacb6bvajqsm6OmcN50Ayl3rcTITNNtNZ33ph1qKmzMkWhiM1LOFvHXmT6LF8Ha2f77RWLkgGm7ms4KxDM3zkNUEtCbobPif8XE1v4b/2U++3DESx7LvcKaITXJRqTgZfGVhUh5r8WnN1c8ZaXpkF+vR6q52gv/ojaAjJ9Qk+QRqa3h3Uh5Y4U3370a50wzinvWaN01uVcuoWGpRs0i7iLlcbvMbHKvhuYcdy/PCnvWviHc0rUPFrk5EAiI8vYGXkRe/yVlvydloIGjCJ7FaaX5UQPCLqQ83WJH3W+DX9PDahq3kGqrO4zDHmFeNLJKU84axH7JBQzuOGQeUi1nR1/oiNNoeBYbhAHnAVJ8lgbQ25naaIvzw8g436UaF00f1MywyU01jWdIu1QbrOUHKuIgUnyaBpxtaP+DJczjMaeRfF65jvRO8Hp1X0YM8/JukuGSeWt66eLIjfRl9HihRgN8Dme8c46Y3qnZMUsw8Zn6I9g8elG7gqfRnWp2CdfyPTU7YjHq56RO4Dlln5od8FeXjjKqxiTZoMYU/xI/AZZrlpk7sM3pAAAAAElFTkSuQmCC>

[image2]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABMAAAAXCAYAAADpwXTaAAAAVUlEQVR4XmNgGAWjgKpgL7oAJeAfugAlwAaIy9AFKQHngNgcXRAETMjEt4B4HwMa8CMTX4NiFgYKwUQg9kYXJAcoAnEnuiC54BO6ACXgMLrAKBhuAACnlhESw2iRqwAAAABJRU5ErkJggg==>

[image3]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACgAAAAYCAYAAACIhL/AAAABv0lEQVR4Xu2VTStFURSGX98MiAFlgIHfIDKRj/ADFAO5GShzJfkJSkkG/oOfYMJEMhITXWWADDCgFPK5Vnsf93jv3nfvm0sG96m3zn3W2vuuTufsA5T5f4yyCNAuqWQZS5dkU7IhaaKai3nJEssIPliEWINZNGN/d0quJU9fHfl0SK5YpmiGf5BayTtLF3qrdZNdLlhe4d9I19WTa5Wc21oSH3uSVZaMbnDGMsUQTM8w+X7JMzkmNGAVCtdxiUADcnd4i/wLws9eaEBF6yMslQGY4g55pgWm7468ugZyTMyAJ5IDloreAV3MzxAzDdN3mHKN1oWIGXAZnp6YxUoWpk+Pk4RB60LE/McUHD1tVuYVHLj6Zh3OhWst0wtHT/L2PHKBmIDp4yMoY32ImAF74OmJWezr6YPbM771aSbh6bmHp2BJDtsaLiD3ZoeIGVCPKm+PFo5YCjcwb3khdK1+rgoRM+Axvp8QedzCbLIP80zqtT64IbRvgaVFz0z9Rl/Y6DWfowm6zxjLUrAoeWBZJBUI3+EfoZtXsyyCbck6y1IyLjllGYl+499Y/gYrkjmWEfzJcAkZFgG6JXUsy5SKT7BCf4Wmd65tAAAAAElFTkSuQmCC>