# **Architectural Manifesto for a Unified Application Substrate: Reconceptualizing Native macOS Systems**

The current paradigm of native macOS application development often relies on a modular but fragmented architecture. This fragmentation manifests as a collection of disparate subsystems, each maintaining its own logic, caches, lifecycle assumptions, and view models. In applications reaching 250,000 lines of code, the cost of this fragmentation—measured in memory bloat, synchronization latency, and developer cognitive load—becomes prohibitive. The proposed reconceptualization shifts the application from a fragmented collection of "features" into a unified substrate: a single, deep ontology expressed through multiple surface expressions. This architectural manifesto details the implementation of a system characterized by a singular identity system, a unified rendering contract, and a zero-copy memory discipline, designed specifically for a macOS 26 target using Swift 6, Rust, and Metal.

## **The Ontological Foundation: Convergence on a Single Truth**

The transition to a unified substrate begins with the elimination of "separate truths" across application layers. Traditional architectures often separate the "core" (frequently in Rust) from the "UI" (in Swift), necessitating expensive serialization protocols like UniFFI to bridge the divide.1 This separation leads to the "11-allocation problem," where a single logical object containing ten children results in eleven separate heap allocations in Swift due to the nature of reference-counted class types.3 In a unified substrate, the internal representation is not a task-bound artifact but a persistent intermediate state that persists across all functional roles.4

The core of this ontology is a "State Mesh"—a distributed graph of state nodes where each node is an Entity\<T\>, a handle to state of type ![][image1] managed by a central application context.5 Unlike standard pointers, these handles provide controlled access through read and update closures, ensuring that any mutation is immediately visible across all surfaces without manual observation or re-fetching.6

### **Identity and the Entity-Component Paradigm**

Maximal coherence requires a singular identity system. In the proposed architecture, every logical component—from a single character in a text buffer to a complex 3D hologram view—shares a common EntityId. This ID remains stable regardless of whether the entity is currently resident in memory, serialized to disk, or being processed by an agentic tool.5

| Concept | Fragmented Paradigm | Unified Substrate (Proposed) |
| :---- | :---- | :---- |
| **Data Identity** | Divided between Swift UUIDs and Rust IDs | Singular EntityId shared across all layers 6 |
| **State Synchronization** | Manual observation (Combine/SwiftUI) | Reactive system with cascade-triggered updates 5 |
| **Object Allocation** | Multiple heap allocations per object | Contiguous memory with inline storage 3 |
| **Truth Propagation** | Polling or event-based re-fetching | Direct handle-based reading via Entity\<T\> 6 |

By utilizing a Redux-inspired but performance-optimized state management system, the application can maintain a "Timeline" of state changes, enabling high-fidelity undo/redo and time-travel debugging across the entire substrate.5 This is critical for collaborative environments where conflict resolution must be handled at the substrate level, using techniques such as last-write-wins based on versioning or more complex CRDT-inspired merging.5

## **Memory Discipline and the Swift 6 Ownership Model**

To achieve minimal cross-layer waste and maximal performance, the application must adopt a strict memory discipline that aligns Swift 6 with Rust’s ownership guarantees. The introduction of non-copyable types (\~Copyable) in Swift 6 is the primary mechanism for this alignment.7 These types ensure unique ownership, eliminating the overhead associated with reference counting and preventing the accidental duplication of resource-heavy objects like file handles or database transactions.7

### **Non-Copyable Types and Zero-Cost Abstractions**

When a type is marked as \~Copyable, it suppresses the implicit conformance to the Copyable protocol, meaning it can only be moved or borrowed, never copied.7 This allows the application to define a "One Ownership Model" where the Rust core manages the lifetime of a resource, and Swift interacts with it through non-copyable shims that enforce the same rules at the language level.8

A function consuming a non-copyable token, for instance, ensures that the token cannot be reused after the call, providing a machine-checked guarantee of single-use behavior.9

![][image2]  
This mathematical restriction on state prevents the data race conditions and "double-free" errors common in C-interop scenarios.8 Furthermore, non-copyable types are stored inline within their containing types, which eliminates the need for separate memory allocations and reduces the pressure on the allocator.7

### **The Borrowing and Yielding Accessor Pattern**

A common bottleneck in native macOS apps is the cost of moving data across the FFI boundary. The proposed architecture replaces traditional value-copying with "Yielding Accessors" and the Span type.10 Swift 6's yielding subscripts allow an accessor to "yield" a reference to a sub-part of a larger structure, allowing the caller to modify it in-place without ever taking ownership or making a copy.10

While some architects argue that \~Escapable and Span introduce unnecessary complexity, the requirements for high-performance systems necessitate these tools for stored references and efficient iterations over non-escaping data.10 By treating "escapability" as a consequence of constraints rather than a first-class property, the application can provide non-escaping guarantees without the syntactic burden of Rust-like lifetime annotations in the majority of the codebase.10

## **Zero-Copy FFI: Beyond the UniFFI Bottleneck**

The current application uses UniFFI to bridge Rust and Swift, but as the application scales to 250,000 lines of code, the binary format translation and serialization overhead of UniFFI become significant.2 To achieve maximal performance and minimal redundant allocations, the architecture must transition to a custom C ABI or a high-performance binding generator like BoltFFI.1

### **Custom ABI and rkyv Integration**

The performance delta between UniFFI and more direct FFI patterns is stark. Benchmarks show that simple operations like echoing an integer can be over 1,000 times faster when bypassing the serialization layers of UniFFI.11

| FFI Strategy | Simple i32 Echo (ns) | 10k Struct Generation (ns) |
| :---- | :---- | :---- |
| **UniFFI** | 1,416 | 12,817,000 |
| **BoltFFI / Custom ABI** | \< 1 | 62,542 |
| **Performance Gain** | **\>1000x** | **205x** |

To facilitate this, the substrate should integrate rkyv, a zero-copy deserialization framework for Rust.12 Unlike serde, which requires parsing a buffer into native types, rkyv ensures that the serialized representation is identical to the in-memory representation of the type.13 This allows the application to mmap a file or a shared memory buffer and cast a pointer directly to the archived type, resulting in ![][image3] access time regardless of the data's scale.13

Total zero-copy deserialization is achieved by structuring encoded bytes with the correct padding and alignment to match the source type’s memory layout:

![][image4]  
This operation involves almost zero CPU work and is ideal for the high-performance, IO-bound nature of a native macOS productivity tool.13

## **The Unified Rendering Contract: Metal and GPUI**

In a fragmented application, each window or pane often has its own rendering logic, leading to redundant GPU buffer allocations and inconsistent visual artifacts. The unified substrate adopts a "Single Rendering Contract" where all UI surfaces are drawn using a custom GPU-accelerated framework inspired by the Zed editor's GPUI.15

### **Data-Driven GPU Delegation and SDF Primitives**

GPUI treats the UI like a game engine, bypassing traditional AppKit drawing in favor of custom Metal shaders for specific primitives.15 Instead of a general-purpose graphics library, the framework focuses on high-performance shaders for rectangles, shadows, text, icons, and images.16 By describing these primitives on the CPU and delegating the drawing to the GPU, the system can achieve 120 FPS even in complex layouts with millions of state changes.16

The framework relies heavily on Signed Distance Functions (SDFs). An SDF returns the distance from a given point to the edge of a mathematically defined object.16 For example, a rectangle centered at the origin is defined by three cases based on the point's position relative to the corner:

1. **Vertical Distance:** If the point is above/left of the corner.  
2. **Horizontal Distance:** If the point is below/right of the corner.  
3. **Pythagorean Distance:** If the point is above and to the right of the corner.16

This mathematical approach allows for perfectly rounded corners and drop shadows without expensive Gaussian blurs.16 For drop shadows, GPUI uses an approximation of the error function (![][image5]) resulting from the convolution of a Gaussian with a step function, allowing for high-quality shadows with a closed-form solution on the GPU.16

### **Metal-cpp and Tile-Based Rendering**

To maintain a maximal native feel while optimizing for Apple Silicon, the renderer uses metal-cpp, a low-overhead C++ interface for Metal.18 This allows the application to utilize Tile-Based Deferred Rendering (TBDR) features explicitly:

* **Memoryless Render Targets:** Storing transient images only in on-chip tile memory to reduce memory bandwidth.19  
* **Tile Shaders:** Providing direct access to the framebuffer cache and threadgroup control for advanced blending and raster order groups.19  
* **Programmable Blending:** Implementing custom transparency and composition rules directly in tile memory.19

By using a single "Scene" struct that organizes primitives into layers, the application ensures that all windows share the same stacking logic and z-index assumptions, preventing the "separate truths" of window-level depth management.16

## **One Action Grammar: Unifying User and Agentic Intent**

A unified substrate requires a "One Action Grammar"—a single system where all user and agent-driven operations are defined as structured data. In this model, an "Action" is a user-defined struct that converts input (keystrokes, mouse clicks, or AI tool calls) into logical operations in the UI.15

### **The Model Context Protocol (MCP) and Tool Orchestration**

For agentic aspirations, the action grammar must be "agent-native." The application acts as an MCP Host, exposing its internal logic through the Model Context Protocol.21 This enables a three-layer architecture:

| Role | Responsibility | Implementation |
| :---- | :---- | :---- |
| **User** | Provides intent and sets goals | Swift/SwiftUI Expressive Surface |
| **LLM (The Brain)** | Strategizes and decides which tools to call | Anthropic/OpenAI via MCP 21 |
| **Agent (Execution)** | Orchestrates the tool calls | Rust-based Agentic Harness 21 |

Each MCP server exposes three building blocks: **Tools** (action-oriented, side-effect-heavy), **Resources** (read-only context), and **Prompts** (user templates).21 In a unified substrate, every "Action" available to the user via a keyboard shortcut (e.g., editor::AlignSelections) is also available as a "Tool" for the agent.20

### **Latent State Transfer and Context Servers**

To maintain coherence during agentic workflows, the system uses Latent State Transfer Protocols (LSTP) to ensure reasoning trajectory preservation across models.23 This allows the agent to "perceive" the application's internal latent state—activations and internal world-model information—rather than just the flattened semantic output.23

The server implements a "Real-Time Resource Subscription Model" using the MCP SDK’s listChanged pattern.24 When a task state changes (e.g., a refactoring task finishes), the server automatically saves the task to disk, emits internal events, and sends push notifications to the subscribed clients.24 This allows the user to start a complex task, move to a different surface expression, and receive a notification on completion without polling for status.24

## **Integrating the Python Sub-Environment: Subinterpreters and the GIL**

A critical requirement for the agentic harness is a robust Python sub-environment for running AI scripts, local embeddings, or data analysis tools. Historically, embedding Python meant dealing with the Global Interpreter Lock (GIL), which limited the application to a single thread of execution for all Python code.25

### **PEP 684 and the Per-Interpreter GIL**

With Python 3.12, the introduction of a per-interpreter GIL (PEP 684\) allows for true parallelism within a single process.25 The application can now create multiple "subinterpreters," each with its own GIL, allowing AI tasks to run on separate threads without blocking the main application logic.25

| Execution Model | GIL Scope | Startup Time | Shared State |
| :---- | :---- | :---- | :---- |
| **Threads** | Process-wide | Extremely Fast | Full (shared objects) 26 |
| **Multiprocessing** | Per-Process | Slow | None (serialization req.) 26 |
| **Subinterpreters** | Per-Interpreter | Fast | None (isolation req.) 25 |

Subinterpreters provide a middle ground: they have the parallelism of multiprocessing but the fast startup of threading.26 Each subinterpreter maintains its own global scope, modules, and built-ins, ensuring that a "runaway" script in one environment does not corrupt the state of another.25 Communication between the main host and the subinterpreters is managed through low-level pipes and structured data exchange, effectively creating a "web worker" model for the native application.26

### **Embedding Strategy and Binary Compactness**

To minimize the binary footprint, the application utilizes python-build-standalone, an effort to provide highly portable and self-contained Python distributions.28 By embedding only the necessary parts of the Python standard library and using LTO (Link-Time Optimization) on the extension modules, the application can reduce the total size increase of embedding Python from \~100MB to a more manageable volume.29

Significantly, the .so binaries in the embedded Python environment must be signed with the application's TeamID to satisfy the Hardened Runtime requirements of the macOS App Store while keeping the Sandbox intact.30 This allows the agentic harness to use optimized C-extensions (like NumPy or PyTorch) without compromising the application's security posture.30

## **Multi-Surface Coherence: The Multi-Window Architecture**

A unified substrate must support multiple windows (surfaces) without creating "separate truths." In a large macOS application, users expect to multitask across multiple pieces of content, but they should never see diverging states.31

### **App-Global vs. Scene-Local State**

The architecture strictly distinguishes between App-global state (Shared Core) and Scene-local state (Per-Window Surface).32

* **App-Global State:** Lives above the scenes in the view hierarchy. It includes authentication, user sessions, the central cache, and the agentic context.32 This state is injected into all windows via environment objects, ensuring mutation in one window is immediately visible in others.32  
* **Scene-Local State:** Includes navigation stacks, selection, focus, and scroll position.32 These are unique to each window instance, allowing the user to have different views of the same underlying data.32

Incorrectly defining a view model (e.g., @StateObject var vm \= GlobalViewModel()) inside a WindowGroup is the most common cause of desynchronization, as it creates a unique instance per window.32 By moving the StateObject to the App struct, the substrate ensures a single instance is shared across all surfaces.32

### **Multi-Window Lifecycle Management**

The application leverages ScenePhase to track the state of individual windows. Because ScenePhase is per-scene, backgrounding one window does not background the entire app.32 This allows the substrate to maintain expensive resources (like a Metal hologram view) only for active, visible scenes while keeping the shared core running for background agentic tasks.32

| Role | Scope | Shared across Windows? |
| :---- | :---- | :---- |
| **Global State** | App-wide | Yes 32 |
| **Services** | App-wide | Yes 32 |
| **Routers** | Per-Window | No 32 |
| **Navigation State** | Per-Window | No 32 |

The system supports multiple scene types—Main, Inspector, Settings, and Auxiliary—all defined within the App body and opened programmatically using the openWindow environment action.32 This allows for a "Many Surface Expressions" model where the user can spawn specialized views of the same deep ontology on demand.32

## **Binary Slimming and Deployment Optimization**

For a 250,000-line application, binary size is a primary performance metric. Rust and Swift can both lead to significantly bloated binaries if not aggressively optimized.33

### **Link-Time Optimization (LTO) and Symbol Stripping**

The architecture employs Link-Time Optimization (LTO) to allow the compiler and linker to optimize across crate and module boundaries.33 By setting lto \= "full" and codegen-units \= 1 in the Rust release profile, the optimizer can perform whole-program analysis, eliminating dead code and optimizing for size across the entire Rust core.33

| Optimization Flag | Effect | Impact on Binary Size |
| :---- | :---- | :---- |
| **strip \= true** | Removes debug info and symbols | \~25% Reduction 33 |
| **opt-level \= "z"** | Aggressively optimizes for size | Significant Reduction 33 |
| **panic \= "abort"** | Removes stack unwinding code | Significant Reduction 33 |
| **LTO \= true** | Cross-crate dead code elimination | Significant Reduction 33 |

On the macOS platform, symbol stripping is a critical step. While debug symbols are necessary for generating dSYMs, they must be stripped from the final binary to prevent bloat.36 Global symbols, which define the public interface, should be stripped from the app binary (since there is no "caller" requiring an interface) while being preserved for internal framework communication.36

### **Optimization of Swift 6 Symbols**

Swift symbols used for scaffolding during compilation can often be stripped post-compilation.36 Using the strip \-ST command on the final Mach-O binary can reduce a framework's size from 35MB to 24MB, a nearly 30% reduction just through correct symbol management.36 Furthermore, by building the standard library from source with LTO enabled, the application can drop unused chunks of the standard library, ensuring the final artifact is as compact as possible.34

## **Implementation Strategy for the Unified Substrate**

The transformation of a fragmented native macOS app into a unified substrate is a three-phase architectural shift:

1. **Phase I: The Shared Substrate:** Establish the Rust-based State Mesh and move all identity management to a singular EntityId system.5 Replace UniFFI with a custom C ABI and rkyv-based zero-copy data loading.11  
2. **Phase II: The Rendering and Action Grammar:** Transition all UI surfaces to a GPUI-inspired renderer using Metal and SDF primitives.15 Define all user interactions as structured "Actions" compatible with both human input and agentic tool calls.20  
3. **Phase III: Agentic and Embedded Runtimes:** Integrate the MCP-based agentic harness and the Python subinterpreter environment.21 Ensure multi-window coherence through a strict distinction between shared global state and per-scene navigation state.32

### **Causal Relationships and Future Outlook**

The causal relationship between memory discipline and rendering performance cannot be overstated. By using zero-copy FFI and non-copyable types, the application ensures that the GPU is always being fed by contiguous, correctly aligned memory buffers, minimizing the CPU overhead of preparing render frames.13

Looking forward, this "Unified Substrate" architecture positions the application to take full advantage of upcoming macOS 26 features, particularly in the realm of local AI and agentic orchestration. By treating the application as a single ontology rather than a fragmented toolset, developers can build more complex, performant, and coherent experiences that maintain a "native feel" while pushing the boundaries of what is possible in a desktop application. The end result is a system that is maximally compact, maximally performance-oriented, and provides a singular, unwavering truth across all surface expressions.

### **Detailed Technical Analysis of SDF Primitives**

To achieve the "one rendering contract," the implementation of Signed Distance Functions (SDFs) must be mathematically rigorous. For the rounded rectangle primitive, which is the "Swiss Army knife" of GPUI rendering, the calculation on the GPU follows a specific symmetry-based logic.16

Let ![][image6] be the point being sampled and ![][image7] be the half-dimensions of the rectangle. The SDF for a rectangle with zero corner radius is defined as:

![][image8]  
To extend this to a rounded rectangle with corner radius ![][image9], the base rectangle is "shrunk" by ![][image9], and the resulting SDF is:

![][image10]  
This allows the shader to handle any corner radius, from sharp 90-degree corners to fully circular pill shapes, using the same code path.16 The fragment shader then uses this distance value to determine the final pixel color, applying anti-aliasing by mapping the distance to an alpha value:

![][image11]  
where ![][image12] represents the width of the anti-aliasing transition, typically matching the pixel density of the display.16 By caching glyphs in a GPU atlas and rendering them using the same alpha-multiplication phase, the system ensures that text and UI elements share the same anti-aliasing and coloring logic, achieving the requested maximal coherence and native feel.16

## **Conclusion on Agentic Harness and Unified State**

The final synthesis of this research dossier confirms that a modular application of 250,000 lines can be successfully unified through a shared ontology and memory discipline. The agentic harness serves as the orchestration layer that "closes the loop" between logic and UI, treating every surface expression as a different way to view the same underlying truth.21 By moving to a subinterpreter model for Python and a zero-copy FFI for Rust, the application eliminates the traditional performance "tax" of cross-language development.11 The resulting substrate is a high-performance, compact, and deeply integrated system that represents the pinnacle of macOS systems architecture for the macOS 26 era.

#### **Works cited**

1. The State of Swift & Rust interoperability? \- Discussion, accessed April 2, 2026, [https://forums.swift.org/t/the-state-of-swift-rust-interoperability/72205](https://forums.swift.org/t/the-state-of-swift-rust-interoperability/72205)  
2. Question on Sendability (Swift 6 data race safety) and FFI interfaces, accessed April 2, 2026, [https://forums.swift.org/t/question-on-sendability-swift-6-data-race-safety-and-ffi-interfaces/76219](https://forums.swift.org/t/question-on-sendability-swift-6-data-race-safety-and-ffi-interfaces/76219)  
3. Rust vs Swift \- Reddit, accessed April 2, 2026, [https://www.reddit.com/r/rust/comments/1kddbf6/rust\_vs\_swift/](https://www.reddit.com/r/rust/comments/1kddbf6/rust_vs_swift/)  
4. Graph is a Substrate Across Data Modalities \- arXiv.org, accessed April 2, 2026, [https://arxiv.org/html/2601.22384v1](https://arxiv.org/html/2601.22384v1)  
5. zed \- crates.io: Rust Package Registry, accessed April 2, 2026, [https://crates.io/crates/zed](https://crates.io/crates/zed)  
6. zed/.rules at main · zed-industries/zed \- GitHub, accessed April 2, 2026, [https://github.com/zed-industries/zed/blob/main/.rules](https://github.com/zed-industries/zed/blob/main/.rules)  
7. Meet Non-Copyable Types – Swift's Secret Performance Boost | Infinum, accessed April 2, 2026, [https://infinum.com/blog/swift-non-copyable-types/](https://infinum.com/blog/swift-non-copyable-types/)  
8. ️ Noncopyable Types in Swift: Safer Code with Ownership and Borrowing \- Commit Studio, accessed April 2, 2026, [https://commitstudiogs.medium.com/%EF%B8%8F-noncopyable-types-in-swift-safer-code-with-ownership-and-borrowing-567d9f9028e8](https://commitstudiogs.medium.com/%EF%B8%8F-noncopyable-types-in-swift-safer-code-with-ownership-and-borrowing-567d9f9028e8)  
9. Introduction to Non-Copyable types \- Swift with Vincent, accessed April 2, 2026, [https://www.swiftwithvincent.com/blog/introduction-to-non-copyable-types](https://www.swiftwithvincent.com/blog/introduction-to-non-copyable-types)  
10. \~Escapable, Span, Ownership Annotations, etc \- Discussion \- Swift ..., accessed April 2, 2026, [https://forums.swift.org/t/escapable-span-ownership-annotations-etc/84566](https://forums.swift.org/t/escapable-span-ownership-annotations-etc/84566)  
11. BoltFFI: a high-performance Rust bindings generator (up to 1,000 ..., accessed April 2, 2026, [https://www.reddit.com/r/rust/comments/1r768bm/boltffi\_a\_highperformance\_rust\_bindings\_generator/](https://www.reddit.com/r/rust/comments/1r768bm/boltffi_a_highperformance_rust_bindings_generator/)  
12. rkyv \- Rust \- Docs.rs, accessed April 2, 2026, [https://docs.rs/rkyv](https://docs.rs/rkyv)  
13. Zero-copy deserialization \- rkyv, accessed April 2, 2026, [https://rkyv.org/zero-copy-deserialization.html](https://rkyv.org/zero-copy-deserialization.html)  
14. rkyv \- Rust, accessed April 2, 2026, [https://doc.qu1x.dev/trackball/rkyv/index.html](https://doc.qu1x.dev/trackball/rkyv/index.html)  
15. zed/crates/gpui/README.md at main · zed-industries/zed · GitHub, accessed April 2, 2026, [https://github.com/zed-industries/zed/blob/main/crates/gpui/README.md](https://github.com/zed-industries/zed/blob/main/crates/gpui/README.md)  
16. Leveraging Rust and the GPU to render user interfaces at 120 FPS ..., accessed April 2, 2026, [https://zed.dev/blog/videogame](https://zed.dev/blog/videogame)  
17. Figma is a Game Engine, Not a Web App: How C++ and WASM Broke the React Ceiling, accessed April 2, 2026, [https://medium.com/@nike\_thana/figma-is-a-game-engine-not-a-web-app-how-c-and-wasm-broke-the-react-ceiling-8ed991bea48f](https://medium.com/@nike_thana/figma-is-a-game-engine-not-a-web-app-how-c-and-wasm-broke-the-react-ceiling-8ed991bea48f)  
18. Get started with Metal-cpp \- Apple Developer, accessed April 2, 2026, [https://developer.apple.com/metal/cpp/](https://developer.apple.com/metal/cpp/)  
19. An experimental real-time renderer on macOS using Metal: clustered lighting, PBR, editor, accessed April 2, 2026, [https://www.reddit.com/r/GraphicsProgramming/comments/1q7fd4i/an\_experimental\_realtime\_renderer\_on\_macos\_using/](https://www.reddit.com/r/GraphicsProgramming/comments/1q7fd4i/an_experimental_realtime_renderer_on_macos_using/)  
20. All Actions \- Zed, accessed April 2, 2026, [https://zed.dev/docs/all-actions](https://zed.dev/docs/all-actions)  
21. A Technical Guide to LLMs, RAGs, Agents, and MCP | by Hristo Stoychev \- Medium, accessed April 2, 2026, [https://medium.com/@h.stoychev87/from-prompts-to-pipelines-a-technical-guide-to-llms-agents-and-mcp-a1068cada7d6](https://medium.com/@h.stoychev87/from-prompts-to-pipelines-a-technical-guide-to-llms-agents-and-mcp-a1068cada7d6)  
22. Stable Releases — Zed, accessed April 2, 2026, [https://zed.dev/releases/stable](https://zed.dev/releases/stable)  
23. Internet of Cognition | Whitepaper \- Outshift | Cisco, accessed April 2, 2026, [https://outshift.cisco.com/internet-of-cognition/whitepaper](https://outshift.cisco.com/internet-of-cognition/whitepaper)  
24. \[Open Source\] I built a build a tool to convert your workstation into a remotely accessible MCP server (run dev tasks like Claude Code remotely from any MCP client...) : r/ClaudeAI \- Reddit, accessed April 2, 2026, [https://www.reddit.com/r/ClaudeAI/comments/1lpstzu/open\_source\_i\_built\_a\_build\_a\_tool\_to\_convert/](https://www.reddit.com/r/ClaudeAI/comments/1lpstzu/open_source_i_built_a_build_a_tool_to_convert/)  
25. Python 3.12 Preview: Subinterpreters, accessed April 2, 2026, [https://realpython.com/python312-subinterpreters/](https://realpython.com/python312-subinterpreters/)  
26. Running Python Parallel Applications with Sub Interpreters \- Anthony Shaw, accessed April 2, 2026, [https://tonybaloney.github.io/posts/sub-interpreter-web-workers.html](https://tonybaloney.github.io/posts/sub-interpreter-web-workers.html)  
27. What are the differences between Python 3.12 sub-interpreters and multithreading/multiprocessing? \- Reddit, accessed April 2, 2026, [https://www.reddit.com/r/Python/comments/16yw7zt/what\_are\_the\_differences\_between\_python\_312/](https://www.reddit.com/r/Python/comments/16yw7zt/what_are_the_differences_between_python_312/)  
28. categories: Personal, PyOxidizer \- Gregory Szorc's, accessed April 2, 2026, [https://gregoryszorc.com/blog/category/pyoxidizer/](https://gregoryszorc.com/blog/category/pyoxidizer/)  
29. python-build-standalone/docs/distributions.rst at main \- GitHub, accessed April 2, 2026, [https://github.com/astral-sh/python-build-standalone/blob/main/docs/distributions.rst](https://github.com/astral-sh/python-build-standalone/blob/main/docs/distributions.rst)  
30. Embedding a Python interpreter inside a MacOS / iOS app, and publishing to the App Store successfully. | by Eldar Eliav | Swift2Go | Medium, accessed April 2, 2026, [https://medium.com/swift2go/embedding-python-interpreter-inside-a-macos-app-and-publish-to-app-store-successfully-309be9fb96a5](https://medium.com/swift2go/embedding-python-interpreter-inside-a-macos-app-and-publish-to-app-store-successfully-309be9fb96a5)  
31. Supporting multiple windows — App Dev Tutorials | Apple Developer Documentation, accessed April 2, 2026, [https://developer.apple.com/tutorials/app-dev-training/supporting-multiple-windows](https://developer.apple.com/tutorials/app-dev-training/supporting-multiple-windows)  
32. SwiftUI Window, Scene & Multi-Window Architecture \- DEV Community, accessed April 2, 2026, [https://dev.to/sebastienlato/swiftui-window-scene-multi-window-architecture-23mi](https://dev.to/sebastienlato/swiftui-window-scene-multi-window-architecture-23mi)  
33. johnthagen/min-sized-rust: 🦀 How to minimize Rust binary size 📦 https://github.com/johnthagen/min-sized-rust · GitHub \- GitHub, accessed April 2, 2026, [https://github.com/johnthagen/min-sized-rust](https://github.com/johnthagen/min-sized-rust)  
34. Optimizing bitdrift's Rust mobile SDK for binary size \- Blog, accessed April 2, 2026, [https://blog.bitdrift.io/post/optimizing-rust-mobile-sdk-binary-size](https://blog.bitdrift.io/post/optimizing-rust-mobile-sdk-binary-size)  
35. Binary Size \- Rust Project Primer, accessed April 2, 2026, [https://rustprojectprimer.com/building/size.html](https://rustprojectprimer.com/building/size.html)  
36. How Can I Inspect the Size Impact of Symbols in an App Binary: A Practical Guide for Apple Developers | TIL with Mohammad, accessed April 2, 2026, [https://mfaani.com/posts/devtools/optimizing-app-size/how-can-i-inspect-the-size-impact-of-symbols-in-an-app-binary/](https://mfaani.com/posts/devtools/optimizing-app-size/how-can-i-inspect-the-size-impact-of-symbols-in-an-app-binary/)  
37. (PDF) The Unified Substrate: Inverting the Universe as a Closed-Loop Transistor Tri-Array, accessed April 2, 2026, [https://www.researchgate.net/publication/403160926\_The\_Unified\_Substrate\_Inverting\_the\_Universe\_as\_a\_Closed-Loop\_Transistor\_Tri-Array](https://www.researchgate.net/publication/403160926_The_Unified_Substrate_Inverting_the_Universe_as_a_Closed-Loop_Transistor_Tri-Array)

[image1]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAA4AAAAYCAYAAADKx8xXAAAAmElEQVR4XmNgGDlgMxD/JwHDAYgThiwAFUNRBAQayGJCDBAbkQETA0TBBTRxEHgEY2wFYkYkCRAoYIBo9EcTZwPiPhgnH0kCBt4zYDoTBASAWBxdEBlg8x9BwMwA0XQGXYIQKGeAaPRGlyAEPjOQ4UwQIMt/oOAmy3+zGSAaE9DEsYIgIP7GAIm7t1AM8ucvBjKcPAoGBAAAiastbKanIo0AAAAASUVORK5CYII=>

[image2]: <data:image/png;base64,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>

[image3]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACgAAAAYCAYAAACIhL/AAAABv0lEQVR4Xu2VTStFURSGX98MiAFlgIHfIDKRj/ADFAO5GShzJfkJSkkG/oOfYMJEMhITXWWADDCgFPK5Vnsf93jv3nfvm0sG96m3zn3W2vuuTufsA5T5f4yyCNAuqWQZS5dkU7IhaaKai3nJEssIPliEWINZNGN/d0quJU9fHfl0SK5YpmiGf5BayTtLF3qrdZNdLlhe4d9I19WTa5Wc21oSH3uSVZaMbnDGMsUQTM8w+X7JMzkmNGAVCtdxiUADcnd4i/wLws9eaEBF6yMslQGY4g55pgWm7468ugZyTMyAJ5IDloreAV3MzxAzDdN3mHKN1oWIGXAZnp6YxUoWpk+Pk4RB60LE/McUHD1tVuYVHLj6Zh3OhWst0wtHT/L2PHKBmIDp4yMoY32ImAF74OmJWezr6YPbM771aSbh6bmHp2BJDtsaLiD3ZoeIGVCPKm+PFo5YCjcwb3khdK1+rgoRM+Axvp8QedzCbLIP80zqtT64IbRvgaVFz0z9Rl/Y6DWfowm6zxjLUrAoeWBZJBUI3+EfoZtXsyyCbck6y1IyLjllGYl+499Y/gYrkjmWEfzJcAkZFgG6JXUsy5SKT7BCf4Wmd65tAAAAAElFTkSuQmCC>

[image4]: <data:image/png;base64,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>

[image5]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAB4AAAAYCAYAAADtaU2/AAABWUlEQVR4Xu2TQStFURSFFyUlJpQfYGKmDIyox0AG/AFSykBPlBIDJUMZiZGRkbEMFSml/AKipEwMjFEyYW1nn+y7u7frpfOU3lers8/aq3vuuedcoME/o5/a9mZqVqhHaof6cL2kyGITOr67XjJ6UeddRvZQw8Lj1BFVcf4yVTVzuSzTZm4ZQHjOM74/9VgmYVhHCI3ofIva1XqOGqWuqBfqlWqiTqh9zVjmEV5Unnev9VImocRFm43XRV1qHT/Xk6kHtZ7SeR7SX/SmRQLXWrcg7NCezYyO4l0Yv93Unm6EfIdvROQsJHBIbSKco+w2D8kNe7OAVZRcrA2UBJRJ/CwXuUFJfgjFAXtrb1Gcy0OyD970SGjWeXLm9heQzLmZlyH5NW965Da/IYRFZ9n2F+L3eLOAVoR8m2+kZgG1HcuvkcVOqTvq2PWS0YmwcJ+OdaVCHXizwZ/yCfboTLOnEOC8AAAAAElFTkSuQmCC>

[image6]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAoAAAAXCAYAAAAyet74AAAAp0lEQVR4XmNgGAXUBOpAPB2IBaB8YyDeAMSmcBVAwAjEl4DYCYj/A/FDIA6Cyv0G4gVQNsNqIGYCYl8GiEIlmAQQdEDFwKAGSp9AFoSCNVjEwAIgd6KLoSjkhgpIIomxQ8XykcQY2qGCyOAREH9DEwP7DqTwAwPE9I1A/ApFBRSAFM0CYmYgDgNiflRpCAAJghTKokugg0kMmO7DCmBBAMLmaHKDAQAA1WwkZEfq36MAAAAASUVORK5CYII=>

[image7]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAgAAAAZCAYAAAAMhW+1AAAAhElEQVR4XmNgGDzgBBD/AuL/QGyGJgcH/QwQBTjBYwYCCkCSh9AFkQFIgSO6IAwkM0AUNALxcygbxbSHUEELJDEQPwCZcxQhBxe7gsxpR8jBxV6AGJJQDg+SJCNUbCKIkwblIINSqJgqiGMH5SADEP8RugAMdKDxwUARKgjC29HkRgIAAFc5JozAqrYVAAAAAElFTkSuQmCC>

[image8]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAmwAAAAqCAYAAAAOCwd9AAAE40lEQVR4Xu3dW+hlYxjH8dcppyFEIUxyhSgzpXHK+RAiF6LUzFzMjKaZGqYZUXK4cOOCxmEuqDFp3EiUQwjZCFduFKKIHIYci8lpwvOz3tc8+/mvvdfetZe9/rvvp57+7/O8e737MBfr7V3vWpMSAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA0DW/xcIAP8fCDPnTtZ9x7SZ/x0IHbY4FAADQXZqYaYKxyNVed+1RvBMLM+CrkL8Q8mHamrB9lqqx944dDbZb7LTYL9Q11v6hBgAAOipOMGLeZNzXd91Si31C7cWQD9Pm7zHu2P718diLLHaEGgAA6KDjU/+J/HqL3V0+Cq3S3BGL81ic2MhLsTBE3fGTMs7YJ1g85/JrLR5wufjLvgAAoGOusdhg8U0avgojD1pcndubch7VHTcp+qz3Wqy2OMjiMYsTc99VFo/nuneTxdsWT4X6WRZLLE7P+WKLky3O+O8VKf3h2sXLIX/UtZ+02MPlbf0Wx6XqEvZtFo+Evjr6Hre6fGGa+9k0ibs01AAAQAfopH2uxTm5/Uro83az2CvXtYdKq29nW2x1r5F43CTdnKrxH7I43+LQnGuiodU9fSb//se6XCuIv7u+23PfjzlXW7E25wekakIY+d/o/lRdMtWE8Ndc0xhlb1lbv4UmieV9TrJ4s797Dr12vcsPy7VonMu9AADgf/CXxZEu9xONg3Pu/ZL/xnpTPmkaX5+9+M7iHpfH9z/GtdW3xuWlplWxslJXaMXOT3KKV137g1RNFj90NY33rWu3IY4b80j961x+SK5F5d8YAAB0RDxh+3xhyIuLU3/9iJCLcq1OtUXjv+/yL1L/pbz4ed7LtRvy3xv7u/+9YzIeI8sslsei6YVce78Od7nG2ubag2ij/xVDQqtgdeJvrpXPYe8jujP0FpcfneqPqasBAIAp8ifnFRavuVzqTt5vpf66JibxsRd1xxVawbt7hBhG47/r8s/T4AmbVt60AleoL66aaU+c6lpV9LS/7c5Qk17I4/dVrr1wpT1pq1L/uBtT8w0DulHCP29N+/b8KmXxQywAAIDp8id9tfe1OC3UItU+zu2yfyyqq02SxveXIL+0uNzl8XsdFXJNcMp3ODBVd1CWPv8MOqnbG9YLuX+/Z1N1d23Rxm+xIO0ad0/XFl3GHfSe/gYK7cPT/j5PK3d3hRoAAJgy3Rmqk7tWq8plwa2u/1PXLvQa7QnTX61M1dEG/LZoj5VW1HQZVCuC3+e2Jm1npup/W1C/HhD7dD5Gn1WhFabLclv0Gh1bJn9fp+rYn3IudZOfnmuXyVOJOOGrO34Sys0Uz4e69qZpX10d3S37kcUbFltCn2j1FAAAzDOnWlwYak0TED0aQneSzoq679tzbV2+fdjlUd3xbWu6pDzIND4rAACYAH8Svy/NfYRHNGsnfT2yQ5NQr+faTd+3qb8Nn8TCCJ5Ig1dMAQDAPKBnkWkf2AWpuqTo94t5/vlks0QrVitd3st/L7E4z+LKXV1zTGPCNi49u+6UWAQAAPOLJmqjKP9jwCxa5tr+uW5NtK+u666LBQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgJnwD280CF7jfor8AAAAAElFTkSuQmCC>

[image9]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAkAAAAZCAYAAADjRwSLAAAAa0lEQVR4XmNgGAVUBz+B+BMQnwBiCyD+A8SPgXghTEEUEBsAsTUQ/wfio1BxEBuEwQCkCwQWIQsCwRcgDoFxaqH0PQZURRxIbDgAKTiALogOQIrs0QWRQQQDqlVYwWUGIhSBfDgFXXAUwAEAV/gX8BpHaDwAAAAASUVORK5CYII=>

[image10]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAmwAAAAqCAYAAAAOCwd9AAAE2UlEQVR4Xu3ca+hlUxjH8ZV7LuOeS5EXlBBDilASyb1IEcNMIzM13iApl3KJRJIXcisiIbeXcgkv3HOZNApvZEKuIRFyf36z1+o85/nvfc7/7+xz9vE/30897bWedc7e+/znxX5mr7V3SgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAMBi90dMtOinmOjQlhY7xmRH7owJAAAweSpU/rG4NA5Mma9jYgzejYkxezBVf3uF93zody2eHwAA6IAuyJvE5BQ53+KbmByDLgoTHdPf3bvftafF8Ra7xCQAAJisLgqVhZjU+W1lcW1Mjpl+25G5raJ5Ur91oab1vAAAWNRutbje4nGLq8PYtPk9JlI1nbhpbj9gsWdvqNEZFlfl9pWpfhp4EoXJURaP5bY/3qcWr7q+bGRxeW5vbfGExTa94dY8lLe7WzzqBzKd50kx2YL7LJak6nfebbFx/zAAALOrFAn75PbmbmzaqDh5OOT2yFud+y+uvSK3m9xgcYfFMxZbWNzWP7zBuAu2Kywuzm1//qV/oeuX3MsW31vcZbF9zrWpPMyh/d6eqsLw497wBiqanwu5UT1isXOqjvtJqgrZtn8bAAD/S19ZnOr6k7hAvhkTNXRXRxft6PQ0905YOWd/7m+HfnRa3uou1pm5/VfeeoP2MSoVQn7/X1gc7foaO8T1ZTeLP/NYofb+rj+q4/K2HEOF4X65Xbxh8XPIjUp3E1em3nH199CdXwAAZtoJaW5BEvvjsDYmGtSdy/JUf+fsplQVFoW+W/f9aNhnND6OKUfRvleHvqf+XiEnyp8V+nVUlA6KQe5Ng9fvPZ2aj6u1f/FYPvx/ECLt89eYBABglmkKyl9097b4zfXH5Z2YaFBXEBxucV1Mpmoab1fX13efcv06Wp9Vdwxv0Limjm8ZEsOKk2H9Y0JO4r9Z/F4btM9BU+Mfpmpatm067jUxCQDALFuV+i/2Wpd0rMWPuf+dxcmpt6ZJF2m5MW81DVe+/5LFsxab5dx7OV8W9R9ksW9u+2O+H3J/W2xnsYPLRa/FROr/rJ6y/Mj1NVaO432Qmo9RDBsfhd/3ibmvIunmnFO//K2LOI2qtgrvtg373XXn1oZhxwUAYCapQNNF8qLcV1vFkqgAK5al3lOYUsbKBVbrymJOyh07n1uftxdYfG7xWeottvfHbLp41+WV+yFvLwljb1l8G3Kiz5b1a020VmucdA5f5raK1bVubEWa+1u1/u+cVK23i2Nt0XTrsH0PG/+vSqEPAADmyRdP51ns5Pqv5225cF+Wek8NzrdgU2GgpwK9F1y7qShQXk9HFktybhAt1F+os1N/kdqF+LtivyulyAQAAB3TqxwOc/0yNerfDVaeFFyfqrtkms5UUaG34R+aqrtGS1P1ypAD8md1d6iszSoFyD2urzt85YEIrVmL9AoOX7isS/UPIhSnWKyJyXmYhuLowNR7bYlMwzk9GRMAAABN9I4yLerXtK6KsibzeYlu9GJMdOiVvNWLavXKDb3wtyt6oe3BMQkAANBkeUy06IiY6Ni2MdGRc2MCAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABg0fsXynj+YniSEqIAAAAASUVORK5CYII=>

[image11]: <data:image/png;base64,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>

[image12]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAA4AAAAZCAYAAAABmx/yAAAApklEQVR4XmNgGAWjAAhmAPF9IP4PxIxI4gVA/AeJD5LfCePoAnE5kkQ6TALKf4XGB2Ew+AGljaGCLDAJKD8PiR8BxGdgnFoo3c2AZBoQMEH5IBfBgAYQT0XigwFI0UskPsgmZINAoAGIxdDEwIrCkPgvoGLI4C8an4GbAVMRiP8MTQweosgApLACyhaH8pENu4/ERgGwUAXhh1CxO0hiwlCxUTD4AADh0Sp0gvlmIgAAAABJRU5ErkJggg==>