# **Architecting a Resilient, Self-Healing macOS Personal Knowledge Management System: Swift 6.2, Rust, and MLX Integration**

## **Part I: The Paradigm of Zero-Downtime Native Computing**

The evolution of personal knowledge management (PKM) systems has transitioned from simple text repositories to hyper-intelligent, agentic ecosystems capable of processing complex queries, synthesizing vast amounts of local data, and operating autonomously. Constructing an application that functions with local and cloud-based Large Language Models (LLMs) via autonomous agentic loops requires an architecture that is categorically intolerant of hangs, data corruption, and crashes. The vision for the "Epistemos" architecture is to achieve a seamless user experience where the software operates with such absolute stability that it appears to never hang, never pause for processing, simply works seamlessly, and never breaks.

The baseline engineering relies on Swift 6.2 for a highly responsive, data-race-free presentation layer, a native Rust core for uncompromising memory safety, and Apple's Foundation Models and MLX frameworks for hardware-accelerated inference. By strictly dictating compiler settings, establishing a rigid five-actor domain map, and employing custom execution contexts, the baseline becomes unbreakable. On top of this, the architecture implements durable execution engines, Erlang-style supervision trees, and circuit breakers to form a self-healing layer that recovers from external instability invisibly.

## **Part II: Baseline Engineering in Swift 6.2**

To avoid relying on developer discipline, the Swift 6.2 compiler must be configured to rigorously enforce correctness.

### **Explicit Swift 6.2 Build Settings**

The project must utilize the following strict upcoming feature flags to eliminate isolation ambiguity and prevent accidental UI blocking:

* NonisolatedNonsendingByDefault: Prevents nonisolated asynchronous methods from indiscriminately hopping to the global concurrent pool, instead inheriting the caller's isolation context, which drastically reduces context-switching overhead.  
* DisableOutwardActorInference: Ensures that property wrappers do not inadvertently leak actor isolation to surrounding code, keeping isolation boundaries perfectly explicit.  
* StrictMemorySafety: Enables Swift 6.2's strict memory safety checks, explicitly flagging any unsafe pointer usages at compile time.

### **The Five-Actor Domain Map**

To prevent deadlocks and maintain clear architectural boundaries, the entire application state is strictly segregated into exactly five isolated actor domains:

1. @MainActor (UI Layer): Solely responsible for SwiftUI view rendering, view model state, and window lifecycle. No computational work is permitted here.  
2. InferenceOrchestrator (Actor): Manages the agentic loop, Foundation Model sessions, MLX allocations, and the prompt queue.  
3. KnowledgeStoreActor (Actor): The exclusive gatekeeper to the local SQLite database and vector embeddings. Ensures single-writer serialization to prevent database locks.  
4. VaultActor (Actor): Handles file system I/O, raw document parsing, and file watching.  
5. NetworkGateway (Actor): Manages all external cloud API calls, streaming connections, and retry logic.

### **Custom SerialExecutors for AVFoundation and SCStream**

Legacy Apple APIs like AVFoundation and ScreenCaptureKit (SCStream) will trigger thread performance checker warnings or 0x8badf00d watchdog crashes if initialized or run on the main thread (e.g., \`\`). To safely integrate these into the actor model, the architecture utilizes custom SerialExecutor patterns.

By defining a custom SerialExecutor backed by a dedicated, private DispatchQueue, the AVActor guarantees that all media streaming setup and teardown occur on a completely isolated thread, explicitly avoiding both the @MainActor and the standard cooperative thread pool.

### **The Absolute Timeout Primitive: withTimeout()**

Because agentic workflows integrate unpredictable network calls and heavy FFI boundaries, no operation is permitted to stall indefinitely. The system enforces a strict withTimeout() wrapper around every operation expected to take over 50ms. This primitive is implemented using withThrowingTaskGroup in a "race-two-tasks" pattern.

The task group spawns two child tasks: one executing the actual payload, and the other executing Task.sleep for the duration of the timeout. The orchestrator calls group.next() to await the first task to finish, and crucially, immediately invokes group.cancelAll() to proactively kill the losing task, preventing memory leaks and orphaned background processes.

## **Part III: The FFI Boundary: Rust, UniFFI, and Tokio**

The core business logic and state machine live in Rust. Bridging this environment with Swift requires strict adherence to concurrency safety and panic handling.

### **Panic Handling via catch\_unwind**

A panic crossing the FFI boundary results in Undefined Behavior (UB) and an immediate SIGKILL. Every single generated UniFFI entry point exported to Swift must be wrapped in std::panic::catch\_unwind. If an unrecoverable logic error occurs in Rust, the catch\_unwind block intercepts it and translates it into a predefined FatalRustError enum, which is safely thrown as a standard Swift error, allowing the Swift AppSupervisor to gracefully restart the workflow.

### **Single Tokio Runtime and JoinError.is\_panic()**

To avoid fighting the macOS kernel over thread allocation, the Rust core initializes a single, shared Tokio runtime via a static OnceLock\<Runtime\>. When executing background asynchronous tasks, errors are checked using Tokio's JoinError.is\_panic(). This recovery pattern allows the Rust backend to detect if a specific spawned worker task panicked, isolate that failure, and use try\_into\_panic to log the telemetry without bringing down the global Tokio runtime or the host Swift application.

### **Cancel-Safety Matrix and tokio::spawn**

Swift's cooperative task cancellation propagates through UniFFI, meaning Rust futures can be dropped mid-execution at any .await point. The architecture enforces a strict Cancel-Safety Matrix:

* **Cancel-Safe (Safe to Drop):** Pure reads, idempotent network GET requests, and channel recv() operations.  
* **Cancel-Unsafe (Unsafe to Drop):** SQLite writes, file system modifications, and multi-step API commits.

To ensure data integrity, any cancel-unsafe operation invoked by Swift must be detached from the Swift task lifecycle. This is achieved by utilizing tokio::spawn to launch the critical work independently. Because tokio::spawn returns a JoinHandle that survives the cancellation of the calling Swift task, the write operation is guaranteed to complete safely in the background even if the user cancels the UI action.

## **Part IV: Foundation Models and Intelligent Fallback**

To provide robust local intelligence, Epistemos integrates Apple's Foundation Models framework alongside cloud fallbacks.

### **Session Recycling and Memory Management**

LanguageModelSession objects maintain conversational state and context history. To prevent "transcript bloat" and unbounded unified memory consumption, sessions are recycled on a strict 10-minute timer. Stale sessions are explicitly deallocated, and the context window is truncated and summarized before a new session is spun up.

### **InferenceBackend Protocol and the Circuit Breaker**

The system uses an abstract InferenceBackend Swift protocol to homogenize interactions between the local Apple Intelligence Foundation Models and external cloud APIs (e.g., Anthropic, OpenAI).

To handle hardware exhaustion or model hallucinations, the InferenceOrchestrator implements an AgentCircuitBreaker:

* **Closed:** Normal operation. All queries route to the local MLX or Foundation Model.  
* **Open:** Triggered by a localized failure, severe DispatchSourceMemoryPressure, or repeated LanguageModelError.guardrailViolation (locale or content restrictions). The circuit opens, and the InferenceBackend protocol seamlessly swaps to the cloud fallback provider.  
* **Half-Open:** After a cooldown period, the circuit tests the local hardware with a small snapshot query. If successful, the circuit closes again.

### **Streaming Snapshot Architecture**

To prevent the UI from locking up while waiting for a long sequence of agentic tokens, the inference backend implements a streaming snapshot architecture. As tokens stream in from the LLM, they are aggregated into a read-only snapshot struct that is published to the @MainActor via an AsyncStream. The UI reacts to these snapshots at 60fps, providing the illusion of instantaneous thought generation.

## **Part V: Agentic Loop and Erlang OTP Supervision**

Multi-step agentic workflows are fragile. The self-healing layer guarantees they recover deterministically.

### **Inner-Loop vs. Outer-Loop Separation**

Agentic reasoning must never be trusted to police its own budget. The architecture splits execution:

* **Inner-Loop (Worker):** Responsible solely for generating the next step, executing the tool, and parsing the output.  
* **Outer-Loop (Supervisor):** Operates outside the LLM's context. It tracks token usage, enforces hard timeouts, and manages the AgentCircuitBreaker. If the inner-loop hallucinates or exceeds its budget, the outer-loop forcefully terminates the task and triggers Reflexion.

### **SQLite Checkpoint-and-Rollback**

To provide durable execution, the Rust core manages an SQLite state machine. Agentic steps are modeled as transactions. Before invoking a tool, the engine creates an SQLite Savepoint. If an agentic step fails midway through execution, the engine issues a rollback() to the last valid checkpoint, restoring the exact workflow context without having to re-execute previous successful LLM steps.

### **AppSupervisor: Erlang OTP-Style Restart Strategies**

Borrowing from Erlang/OTP principles, the Rust and Swift actor supervision trees are designed to embrace and manage failure. The AppSupervisor monitors all background actor processes and worker threads using defined strategies:

* one\_for\_one: If a specific background parsing worker crashes, only that worker is restarted.  
* rest\_for\_one: If the Knowledge Store database actor fails, it and all dependent downstream indexing workers are restarted.  
* one\_for\_all: If the overarching InferenceOrchestrator encounters a fatal panic, the entire agentic loop environment is aggressively torn down and restarted from a clean slate to prevent corrupted state leaks.

## **Part VI: Complete Stack-Layer Diagram**

| Layer | Component | Primary Responsibility | Concurrency / Safety Rule |
| :---- | :---- | :---- | :---- |
| **Presentation** | SwiftUI Views & ViewModels | Render UI, bind to AppState. | @MainActor isolated; pure observations. |
| **Swift Orchestration** | InferenceOrchestrator, VaultActor | Manage app flow, Foundation Models, I/O. | Strict Actor isolation; Sendable only. |
| **Hardware Int.** | AVActor, custom SerialExecutor | Capture screen, mic (SCStream). | Bound to private DispatchQueue. |
| **Boundary** | UniFFI \+ catch\_unwind | Bridge Swift to Rust securely. | Zero panics allowed; throws Swift Errors. |
| **Rust Core** | Tokio Runtime (OnceLock) | Execute parallel heavy data processing. | Scoped lifetimes; detached spawned tasks. |
| **Durable Exec.** | SQLite WAL Checkpoint DB | Store agentic graphs, vector metadata. | Atomic commits; deterministic rollback. |
| **Inference Engine** | MLX / Foundation Models | Generate LLM outputs, tool calling. | AgentCircuitBreaker bounded fallback. |

## **Part VII: Failure-Mode Coverage Matrix**

| Failure Mode | Detection Mechanism | Recovery / Self-Healing Action |
| :---- | :---- | :---- |
| **Main Thread Hang** | Secondary Watchdog Thread timeout. | Process relaunch / soft restart via SMAppService. |
| **Async Task Stall** | withTimeout() TaskGroup timeout. | Cooperative cancellation; forcefully throw CancellationError. |
| **Hardware Swapping** | DispatchSourceMemoryPressure critical. | Circuit Breaker: Evict local model, fallback to Cloud API. |
| **LLM Hallucination** | Outer-Loop Schema Validator. | Reflexion: Auto-inject error into prompt and loop back. |
| **Rust Panic** | catch\_unwind / JoinError.is\_panic(). | Capture to FatalRustError, one\_for\_one worker restart. |
| **Workflow Interruption** | SQLite Checkpoint miss. | Durable Execution: Rollback to last Savepoint, replay deterministic steps. |
| **Apple Intel. Reject** | LanguageModelError.guardrailViolation | Sanitize prompt, rotate to secondary local model or fallback. |

## **Part VIII: Sequenced 20-Item Task List for Claude Code Implementation**

1. **Project Setup:** Initialize Swift 6.2 Xcode project; configure NonisolatedNonsendingByDefault, DisableOutwardActorInference, and StrictMemorySafety flags.  
2. **Rust Initialization:** Create Cargo.toml with tokio, rusqlite, and uniffi; configure panic \= "abort" for release builds.  
3. **Tokio Setup:** Implement the static OnceLock\<Runtime\> in Rust for the single shared async executor.  
4. **FFI Boundary:** Write the UniFFI UDL/macro bindings; wrap all exported Rust functions in catch\_unwind closures.  
5. **Error Mapping:** Map the catch\_unwind panics to a FatalRustError enum in Swift.  
6. **Domain Map Definition:** Create the baseline Swift actors: InferenceOrchestrator, KnowledgeStoreActor, VaultActor, and NetworkGateway.  
7. **Watchdog Setup:** Implement the background CFRunLoopObserver watchdog to monitor @MainActor responsiveness.  
8. **Custom Executors:** Build the SerialExecutor over a DispatchQueue for AVFoundation and SCStream interactions.  
9. **Timeout Primitive:** Implement the withTimeout() function utilizing withThrowingTaskGroup and race-two-tasks cancellation.  
10. **Database Schema:** Design the SQLite WAL schema in Rust with specific execution\_log tables for checkpointing.  
11. **Durable Engine:** Implement SQLite Savepoint creation and rollback() logic in Rust for agentic step tracking.  
12. **Cancel-Safety Integration:** Wrap all SQLite writes in tokio::spawn to protect them from Swift CancellationError drops.  
13. **Supervision Tree:** Build the Erlang-style AppSupervisor in Rust with one\_for\_one, rest\_for\_one, and one\_for\_all strategies.  
14. **JoinError Handling:** Implement JoinError.is\_panic() checks in the Rust supervisor to catch and isolate worker thread crashes.  
15. **InferenceBackend Protocol:** Define the InferenceBackend protocol in Swift with implementations for Apple Foundation Models and Cloud APIs.  
16. **Session Management:** Implement the 10-minute LanguageModelSession recycling loop to prevent context bloat.  
17. **Circuit Breaker:** Construct the AgentCircuitBreaker (Closed/Open/HalfOpen) linked to memory pressure and API failures.  
18. **Streaming Snapshots:** Build the AsyncStream snapshot publisher to push non-blocking token updates to the UI.  
19. **Outer-Loop Validation:** Implement the Outer-Loop supervisor in Swift to validate LLM schemas and trigger Reflexion on failure.  
20. **End-to-End Test:** Execute a complex agentic loop simulating a crash mid-workflow to verify SQLite durable resumption and UI stability.