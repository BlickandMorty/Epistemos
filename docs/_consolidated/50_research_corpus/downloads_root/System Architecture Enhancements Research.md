# **Architectural Resilience and Security Hardening in Distributed Systems: A Multi-Domain Analysis of Concurrency, Durability, and Isolation**

The integration of advanced security, performance, and reliability fixes into modern system architectures represents a fundamental shift from traditional monolithic design toward decentralized, isolated, and durable execution paradigms. As distributed environments face increasing pressure from sophisticated adversarial threats and the demand for high-throughput media processing, the implementation of robust isolation boundaries and fault-tolerant mechanisms becomes paramount. This report examines the technical execution of a high-security architecture, specifically focusing on the refactoring of actor-based domains, the customization of execution contexts for specialized workloads, and the deployment of durable engines to ensure system integrity and availability.

## **I. Five-Actor Domain Refactoring and Region-Based Isolation Boundaries**

The transition to Swift 6 and the subsequent implementation of strict concurrency checking necessitates a comprehensive refactoring of application state into specialized isolation domains. In high-security environments, this is achieved through a five-actor model, which separates system responsibilities into KnowledgeStore, Inference, Vault, Network, and Telemetry. These actors serve as the primary defensive units, ensuring that only a single task can access internal state at a given time, thereby eliminating data races.1

### **Structural Evolution of Isolation Domains**

In the current architectural landscape, the compiler enforces "Sendable" requirements to ensure that objects passing between isolation domains are safe for concurrent access.1 Region-based isolation, introduced in 2026, allows the compiler to prove that a value is safe to pass if it has no other references, significantly reducing the overhead of manual Sendable conformance.1 This evolution allows for a more fluid interaction between the five core actor domains while maintaining strict memory safety.

The refactoring process involves moving database managers and network clients into dedicated actors to prevent concurrent access to shared mutable state.1 The implementation of the five-actor model is detailed in the table below:

| Actor Domain | Architectural Responsibility | Primary Safety Mechanism | Data Sensitivity |
| :---- | :---- | :---- | :---- |
| **KnowledgeStore** | Semantic data management and graph persistence. | Actor-isolated local state with strict Sendable enforcement. | High (User Knowledge) |
| **Inference** | Model execution, tensor management, and prompt engineering. | Integration with ThermalGuard and CircuitBreakers. | Moderate (Compute) |
| **Vault** | Credential management, key derivation, and secure imports. | Off-main-thread execution via dedicated executors. | Critical (Secrets) |
| **Network** | Secure external API communication and P2P synchronization. | OHTTP-based request wrapping and differential privacy. | Moderate (Metadata) |
| **Telemetry** | System health monitoring and keystroke timing analysis. | Differential privacy with noise injection and ZK-Proofs. | High (Biometrics) |

### **Memory Safety and Structured Concurrency**

Modern projects utilize structured concurrency to ensure that updates occur on the correct actor domain. In 2026, attempts to access UI-bound elements from a background actor trigger hard compiler errors, providing a safety net that eliminates the "purple warnings" of earlier frameworks.1 The primary mechanism for protecting state is the restriction of direct access to stored instance properties, requiring all cross-actor interaction to occur asynchronously.2 This architectural constraint forces developers to acknowledge "suspension points," where state might change while a task is suspended, necessitating the re-validation of assumptions after every await.2

## **II. Custom SerialExecutors for High-Throughput Media Processing**

Standard actors execute tasks on a shared global concurrent pool, which lacks thread affinity and can lead to non-deterministic performance in media-heavy applications.4 For frameworks such as ScreenCaptureKit (SCStream) and AVFoundation, which require consistent throughput to avoid frame drops, the implementation of custom SerialExecutor protocols is a critical optimization.5

### **Implementation of Specialized Executors**

Custom executors allow actors to influence exactly where their asynchronous work is executed while upholding mutual exclusion.5 By conforming a type to the SerialExecutor protocol and implementing the enqueue(\_:) method, architects can pin media processing tasks to dedicated high-priority threads.4 This prevents heavy blocking operations, such as I/O or frame encoding, from starving other actors in the global pool.4

For SCStream and AVFoundation integration, an actor such as MediaStreamHandler overrides the unownedExecutor property to point to a custom MediaProcessingExecutor.5 This ensures that even when the actor is invoked from the @MainActor, the actual work "hops" to an optimized media context, effectively preventing main-thread hangs.5

### **Performance Optimization through Executor Equality**

The runtime utilizes complex equality semantics to compare executors. If two actors share the same serial executor, the system can optimize the context switching between them, reducing the "abstraction cost".5 This is essential for media pipelines where millisecond-level latency determines the stability of the stream. Developers utilize MainActor.assumeIsolated to access isolated state synchronously when the context is guaranteed, further reducing the overhead of asynchronous hops in performance-critical code paths.5

## **III. Off-Main-Thread Vault Imports and Credential Security**

The "Vault" domain represents the most sensitive layer of the architecture, responsible for the ingestion and storage of cryptographic keys and user credentials. To maintain system responsiveness, vault imports must be handled off-main-thread, utilizing dedicated executors that isolate the computationally expensive work of key derivation and encryption.8

### **Security Implications of Off-Main-Thread Execution**

Performing vault imports on the main thread not only risks UI hangs but also increases the attack surface for side-channel attacks by interleaving sensitive cryptographic operations with standard UI event processing. By moving these operations to an isolated actor with a custom serial executor, the system ensures that credential processing is decoupled from the main thread's execution context.5

| Feature | Main-Thread Import (Legacy) | Off-Main-Thread Vault (2026) |
| :---- | :---- | :---- |
| **UI Responsiveness** | Potential for hangs during key derivation. | Zero impact on UI latency. |
| **Memory Isolation** | Shared global concurrent pool access. | Dedicated serial executor context. |
| **Attack Surface** | High (Context-switching with UI). | Low (Isolated cryptographic domain). |
| **Safety** | Subject to actor contention. | Guaranteed mutual exclusion. |

## **IV. AppSupervisor: Implementing OTP Restart Strategies and Fault Tolerance**

Achieving 99.99% uptime requires a departure from traditional error-handling models toward the Erlang/OTP philosophy of "organized failure".9 The AppSupervisor framework implements hierarchical supervision trees where supervisors monitor worker processes and restart them according to predefined strategies.10

### **Supervision Strategies and Hierarchy**

The architecture utilizes three primary restart strategies to manage component failure:

1. **one\_for\_one**: Only the failed child process is restarted. This is the default for independent workers such as individual network requests or telemetry collectors.9  
2. **one\_for\_all**: If one child process fails, all child processes in the supervision group are restarted. This is used for tightly coupled components where a failure in one invalidates the state of others, such as an inference engine and its local cache.9  
3. **rest\_for\_one**: If a child fails, it and all subsequent processes started after it are restarted. This is critical for ordered pipelines where downstream workers depend on the initialization of upstream ones.9

### **Restart Tolerance and System Stability**

To prevent infinite restart loops, supervisors implement restart tolerance metrics, such as a maximum of three restarts within a sixty-second period.9 If this threshold is exceeded, the failure cascades to the parent supervisor, allowing the system to degrade gracefully rather than continuing to consume resources on a non-recoverable component.9 In Rust, this is implemented via the supertrees crate, which leverages the Tokio runtime for cooperative multitasking while maintaining process isolation.13

## **V. EpistemosMode: State Machine for Graceful Service Degradation**

System resilience is further enhanced by the EpistemosMode degradation state machine, which allows the architecture to maintain core functionality even under resource constraints or network failure.15 This "capability degradation" model ensures that the system bends instead of breaking.16

### **Operational States of EpistemosMode**

The state machine manages transitions between five distinct levels of service:

* **Full**: All capabilities are active, including multi-turn conversation, complex reasoning, and cloud-based synchronization.16  
* **DegradedAI**: High-complexity models are disabled. The system reverts to single-turn responses and basic natural language understanding (NLU).16  
* **DegradedCloud**: Real-time cloud features are suspended. The system prioritizes local processing and background indexing to save bandwidth and power.16  
* **LocalOnly**: Network access is completely severed. The system relies on keyword matching and predefined local responses, ensuring data remains on-device.16  
* **ReadOnly**: All mutations to the KnowledgeStore are blocked to preserve data integrity during critical power loss or system instability.

Transitions between these states are triggered by system health metrics, thermal pressure, or connectivity changes, with hooks like \_on\_degrade() and \_on\_restore() managing the cleanup of transient state.16

## **VI. Apple Intelligence Service: 10-Minute Session Recycling and Transparency**

Session management within the Apple Intelligence Service is governed by strict privacy protocols, including the mandatory 10-minute recycling of session identifiers.8 This practice mitigates the risk of long-term tracking and session hijacking in AI-driven interactions.

### **Recycling Mechanism and Memory Security**

To prevent session fixation attacks, the system regenerates session IDs upon logout, inactivity, or every 10 minutes of active use.8 These IDs are generated using high-entropy cryptographic algorithms to ensure unpredictability.8 Furthermore, all processing for Apple Intelligence occurs on-device or within Private Cloud Compute, with zero cloud dependency for data summaries and action items.18

| Metric | Standard Session Management | Apple Intelligence (AI-S) |
| :---- | :---- | :---- |
| **Recycle Interval** | 24 Hours (Absolute) | 10 Minutes (Rolling) |
| **Entropy** | 128-bit | 256-bit |
| **Storage** | Server-side (Redis) | Local Secure Enclave / Vault |
| **Data Residency** | Cloud-based | On-Device (Neural Engine) |

Transparency logging allows users to review exactly what data was processed by the Intelligence Service. The report identifies which requests were handled on-device and which required Private Cloud Compute, ensuring that users have a granular view of their data's lifecycle.17

## **VII. Rust FFI Hardening: Boundary Protection and bridge.rs Management**

Interfacing Rust with foreign code via FFI introduces significant risks to memory safety and system stability. The architecture addresses these risks through a hardened bridge.rs layer, utilizing catch\_unwind to prevent Rust panics from crossing the language boundary.19

### **Exception Safety and catch\_unwind**

Rust functions called from foreign code must be defined using extern "C", which ensures an automatic abort if a panic occurs.21 However, for more graceful error handling, catch\_unwind is used to capture panics and convert them into Result types that the host language can process.21 This is particularly critical in the Inference domain, where model loading or tensor allocation might fail unpredictably.

The use of the AssertUnwindSafe wrapper ensures that captured variables do not violate exception safety requirements, although architects are encouraged to use catch\_unwind sparingly and rely on Result for expected error paths.20

### **Wiring withTimeout to FFI and Inference Paths**

A common failure mode in FFI calls is the "hanging" function that does not respond to cooperative cancellation.22 To mitigate this, the architecture wires withTimeout to FFI and inference paths.22 Since standard task groups must wait for all children to complete, a hanging call would block the group indefinitely.23

The solution involves spinning off the FFI call into an unstructured Task, allowing the withTimeout function to return to the caller once the deadline is reached, even if the underlying FFI call remains suspended in the background.22 This pattern "abandons" the result of the hanging call, ensuring system-wide responsiveness at the cost of a leaked task that eventually times out or is reclaimed by the operating system.22

## **VIII. AgentCircuitBreaker and ThermalGuard: Inference Guardrails**

To protect system resources during intensive AI operations, the architecture integrates the AgentCircuitBreaker and ThermalGuard mechanisms.

### **Circuit Breaker Dynamics**

The AgentCircuitBreaker monitors the failure rate of the Inference actor. If the model fails to produce valid outputs or exceeds latency thresholds repeatedly, the circuit trips, diverting requests to the DegradedAI state of the EpistemosMode state machine.26 This prevents the system from being overwhelmed by a failing model and provides time for the inference engine to reset.9

### **ThermalGuard and Hardware Protection**

The ThermalGuard acts as a physical layer of defense. It monitors the temperature of the Neural Engine and CPU. Upon detecting thermal pressure, it triggers a suspension of non-critical inference tasks, such as background audio transcription or screen indexing.18 This proactive suspension ensures that critical OS functions remain responsive and prevents hardware damage due to overheating.

## **IX. Input Telemetry and Keystroke Timing Analysis**

Telemetry regarding user input is a double-edged sword: it is essential for identifying behavioral patterns and preventing bot attacks, yet it contains sensitive biometric data.28 The architecture utilizes differential privacy and zero-knowledge proofs to protect this data.

### **Privacy-Preserving Keystroke Telemetry**

Keystroke dynamics—including dwell time, flight time, and typing rhythm—are distinctive enough to identify individuals and even detect medical conditions like early-stage Parkinson's.28 To protect this, the system implements a privacy-preserving telemetry scheme:

1. **Noise Injection**: Calibrated noise is added to timing data before transmission, hiding individual data points while preserving overall trends.31  
2. **OHTTP Wrapping**: Telemetry is sent via Oblivious HTTP, stripping client IP addresses and ensuring the ingestor cannot link data to a specific user.31  
3. **ZK-PoP (Zero-Knowledge Proof of Process)**: The system generates a zero-knowledge proof that a typing session was human-authored without revealing the actual keystrokes or timing intervals.28

This attestation proves that the work function was computed correctly and that behavioral feature vectors fall within human population distributions, utilizing Pedersen commitments and Bulletproof range proofs to maintain anonymity.28

## **X. Durable Execution: Event Sourcing and the Rust-Based Bifrost Engine**

For long-running processes that must survive system reboots or crashes, the architecture employs a durable execution engine built in Rust.26 This engine externalizes the program's memory and scheduling, ensuring that state is never lost.26

### **Bifrost Log Architecture and Event Sourcing**

The heart of the durable engine is the **Bifrost** log, a distributed, replicated, and segmented log that serves as the primary durability layer.34 All state changes—invocations, journal entries, and state updates—are persisted in the log before being applied.34

* **Log-Structured Design**: The system acts on a command log loop where the processor tails the log and materializes state in an embedded RocksDB instance.34  
* **Event Replay**: Upon recovery, the worker reconstructs the workflow state by replaying events from the log. This enables deterministic resumption of tasks without the need for manual state serialization.26  
* **Tiered Storage**: RocksDB state is periodically snapshotted to an object store (e.g., S3), allowing the log to be trimmed and ensuring the system scales efficiently.34

### **Determinism and Side-Effect Management**

Durable execution requires that workflow code be strictly deterministic. Any side effects, such as network or database calls, must be pushed into individual tasks managed by the engine.37 The engine caches the results of these tasks, ensuring that during replay, the function receives the same outputs it did in the original run.26 This architecture achieved 99.99% uptime in production environments, significantly reducing manual interventions and preventing cascading failures.9

## **XI. Integration and Conclusion**

The convergence of these architectural fixes creates a system that is not only performant but inherently resilient and secure. By refactoring into specialized actor domains and utilizing custom executors for media, the system achieves deterministic performance in complex workloads. The implementation of supervision trees and degradation state machines ensures that the application remains functional under adverse conditions, while the use of zero-knowledge telemetry and 10-minute session recycling provides a robust privacy framework for AI-driven interactions. Finally, the deployment of a Rust-based durable execution engine ensures that critical workflows are immune to system instability, representing the pinnacle of modern, fault-tolerant software engineering.

The systematic application of these principles transforms the architecture from a collection of services into a cohesive, self-healing environment capable of navigating the complexities of 2026's digital landscape. Through the combination of Swift's actor isolation and Rust's memory-safe durable execution, architects can build systems that are genuinely "bulletproof," protecting both user data and system availability at every level of the stack.

#### **Works cited**

1. Mastering Actor Isolation and Swift 6 Concurrency 2026 | by Devin ..., accessed March 31, 2026, [https://blog.stackademic.com/mastering-actor-isolation-and-swift-6-concurrency-2026-34e27c208b51](https://blog.stackademic.com/mastering-actor-isolation-and-swift-6-concurrency-2026-34e27c208b51)  
2. WWDC21: Protect Mutable State with Swift Actors \- CapTech, accessed March 31, 2026, [https://www.captechconsulting.com/technical/wwdc21-protect-mutable-state-with-swift-actors](https://www.captechconsulting.com/technical/wwdc21-protect-mutable-state-with-swift-actors)  
3. Actor-Based Isolation in Swift: A Complete Guide | by Dhrumil Raval \- Medium, accessed March 31, 2026, [https://medium.com/@dhrumilraval212/actor-based-isolation-in-swift-a-complete-guide-383a3a993a4b](https://medium.com/@dhrumilraval212/actor-based-isolation-in-swift-a-complete-guide-383a3a993a4b)  
4. SerialExecutor | Apple Developer Documentation, accessed March 31, 2026, [https://developer.apple.com/documentation/swift/serialexecutor](https://developer.apple.com/documentation/swift/serialexecutor)  
5. swift-evolution/proposals/0392-custom-actor-executors.md at main ..., accessed March 31, 2026, [https://github.com/swiftlang/swift-evolution/blob/main/proposals/0392-custom-actor-executors.md](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0392-custom-actor-executors.md)  
6. Build Your Own Actor Executor in Swift | Medium, accessed March 31, 2026, [https://medium.com/@emilioarvonio/build-your-own-actor-executor-in-swift-dbaa4bf7718f](https://medium.com/@emilioarvonio/build-your-own-actor-executor-in-swift-dbaa4bf7718f)  
7. Swift assumeIsolated Guide \- Claude Code Skill \- MCP Market, accessed March 31, 2026, [https://mcpmarket.com/tools/skills/swift-actor-isolation-guard](https://mcpmarket.com/tools/skills/swift-actor-isolation-guard)  
8. Session management best practices — WorkOS, accessed March 31, 2026, [https://workos.com/blog/session-management-best-practices](https://workos.com/blog/session-management-best-practices)  
9. The Supervision Tree Patterns That Make Systems Bulletproof | by The Latency Gambler, accessed March 31, 2026, [https://medium.com/@kanishks772/the-supervision-tree-patterns-that-make-systems-bulletproof-356199f178bb](https://medium.com/@kanishks772/the-supervision-tree-patterns-that-make-systems-bulletproof-356199f178bb)  
10. OTP Supervisors \- Elixir School, accessed March 31, 2026, [https://elixirschool.com/en/lessons/advanced/otp\_supervisors](https://elixirschool.com/en/lessons/advanced/otp_supervisors)  
11. Overview — Erlang System Documentation v28.4.1, accessed March 31, 2026, [https://www.erlang.org/doc/system/design\_principles.html](https://www.erlang.org/doc/system/design_principles.html)  
12. gleam/otp/factory\_supervisor · gleam\_otp · v1.2.0, accessed March 31, 2026, [https://hexdocs.pm/gleam\_otp/gleam/otp/factory\_supervisor.html](https://hexdocs.pm/gleam_otp/gleam/otp/factory_supervisor.html)  
13. Crate supertrees \- Rust \- Docs.rs, accessed March 31, 2026, [https://docs.rs/supertrees](https://docs.rs/supertrees)  
14. supertrees \- Rust \- Docs.rs, accessed March 31, 2026, [https://docs.rs/supertrees/latest/supertrees/](https://docs.rs/supertrees/latest/supertrees/)  
15. System Design Roadmap (@systemdr): "Graceful Service Degradation Patterns When Your System Starts Falling Apart (But Keeps Working) You're watching Netflix during a thunderstorm when your internet connection becomes spotty. Instead of the video stopping completely, it automatically switches to lower quality, b…" \- Substack, accessed March 31, 2026, [https://substack.com/@systemdr/note/c-231383686](https://substack.com/@systemdr/note/c-231383686)  
16. Graceful Degradation Patterns \- PraisonAI, accessed March 31, 2026, [https://docs.praison.ai/docs/best-practices/graceful-degradation](https://docs.praison.ai/docs/best-practices/graceful-degradation)  
17. Apple Users: “Apple Intelligence Reports” on YOU being sent every 15 min \- Reddit, accessed March 31, 2026, [https://www.reddit.com/r/privacy/comments/1i7mlh0/apple\_users\_apple\_intelligence\_reports\_on\_you/](https://www.reddit.com/r/privacy/comments/1i7mlh0/apple_users_apple_intelligence_reports_on_you/)  
18. Apple Intelligence — on-device daily summaries & auto reminders \- Screenpipe \- Mintlify, accessed March 31, 2026, [https://mintlify.com/screenpipe/screenpipe/integrations/apple-intelligence](https://mintlify.com/screenpipe/screenpipe/integrations/apple-intelligence)  
19. How to Create Safe FFI Bindings in Rust \- OneUptime, accessed March 31, 2026, [https://oneuptime.com/blog/post/2026-01-30-rust-safe-ffi-bindings/view](https://oneuptime.com/blog/post/2026-01-30-rust-safe-ffi-bindings/view)  
20. Unwinding \- The Rustonomicon, accessed March 31, 2026, [https://doc.rust-lang.org/nomicon/unwinding.html](https://doc.rust-lang.org/nomicon/unwinding.html)  
21. catch\_unwind in std::panic \- Rust, accessed March 31, 2026, [https://doc.rust-lang.org/std/panic/fn.catch\_unwind.html](https://doc.rust-lang.org/std/panic/fn.catch_unwind.html)  
22. Is this a good implementation of \`withTimeout\`? \- Using Swift \- Swift ..., accessed March 31, 2026, [https://forums.swift.org/t/is-this-a-good-implementation-of-withtimeout/83613](https://forums.swift.org/t/is-this-a-good-implementation-of-withtimeout/83613)  
23. Implementing Task timeout with Swift Concurrency \- Donny Wals, accessed March 31, 2026, [https://www.donnywals.com/implementing-task-timeout-with-swift-concurrency/](https://www.donnywals.com/implementing-task-timeout-with-swift-concurrency/)  
24. Running an async task with a timeout \- Swift Forums, accessed March 31, 2026, [https://forums.swift.org/t/running-an-async-task-with-a-timeout/49733](https://forums.swift.org/t/running-an-async-task-with-a-timeout/49733)  
25. Swift: Have a timeout for async/await function \- Stack Overflow, accessed March 31, 2026, [https://stackoverflow.com/questions/75019438/swift-have-a-timeout-for-async-await-function](https://stackoverflow.com/questions/75019438/swift-have-a-timeout-for-async-await-function)  
26. The Principles of Durable Execution Explained \- Inngest Blog, accessed March 31, 2026, [https://www.inngest.com/blog/principles-of-durable-execution](https://www.inngest.com/blog/principles-of-durable-execution)  
27. Building Production-Ready AI Workflows with Rust: An Event-Sourced Approach, accessed March 31, 2026, [https://dev.to/bredmond1019/building-production-ready-ai-workflows-with-rust-an-event-sourced-approach-5142](https://dev.to/bredmond1019/building-production-ready-ai-workflows-with-rust-an-event-sourced-approach-5142)  
28. Privacy-Preserving Proof of Human Authorship via Zero ... \- arXiv, accessed March 31, 2026, [https://arxiv.org/pdf/2603.00179](https://arxiv.org/pdf/2603.00179)  
29. A Generic Privacy-preserving Protocol for Keystroke Dynamics-based Continuous Authentication \- SciTePress, accessed March 31, 2026, [https://www.scitepress.org/Papers/2022/111414/111414.pdf](https://www.scitepress.org/Papers/2022/111414/111414.pdf)  
30. Enhancing security and usability with context aware multi-biometric fusion for continuous user authentication \- PMC, accessed March 31, 2026, [https://pmc.ncbi.nlm.nih.gov/articles/PMC12368039/](https://pmc.ncbi.nlm.nih.gov/articles/PMC12368039/)  
31. \[2507.06350\] An Architecture for Privacy-Preserving Telemetry Scheme \- arXiv, accessed March 31, 2026, [https://arxiv.org/abs/2507.06350](https://arxiv.org/abs/2507.06350)  
32. Privacy-preserving experimentation: Sensitive data techniques \- Statsig, accessed March 31, 2026, [https://www.statsig.com/perspectives/privacy-preserving-experimentation-techniques](https://www.statsig.com/perspectives/privacy-preserving-experimentation-techniques)  
33. An Architecture for Privacy-Preserving Telemetry Scheme \- arXiv, accessed March 31, 2026, [https://arxiv.org/html/2507.06350v1](https://arxiv.org/html/2507.06350v1)  
34. Building a modern Durable Execution Engine from First Principles ..., accessed March 31, 2026, [https://restate.dev/blog/building-a-modern-durable-execution-engine-from-first-principles/](https://restate.dev/blog/building-a-modern-durable-execution-engine-from-first-principles/)  
35. Event Sourcing Implementation \- Temporal Server \- Mintlify, accessed March 31, 2026, [https://www.mintlify.com/temporalio/temporal/architecture/event-sourcing](https://www.mintlify.com/temporalio/temporal/architecture/event-sourcing)  
36. Durable Execution: This Changes Everything : r/programming \- Reddit, accessed March 31, 2026, [https://www.reddit.com/r/programming/comments/1j9ncni/durable\_execution\_this\_changes\_everything/](https://www.reddit.com/r/programming/comments/1j9ncni/durable_execution_this_changes_everything/)  
37. How to think about durable execution \- Hatchet, accessed March 31, 2026, [https://hatchet.run/blog/durable-execution](https://hatchet.run/blog/durable-execution)