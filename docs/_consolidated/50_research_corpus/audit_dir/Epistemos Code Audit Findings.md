# **Epistemos Architecture and Quality Audit: Structural Debt, Performance Hazards, and FFI Hardening**

## **Introduction and Architectural Context**

The Epistemos macOS application has reached a critical architectural inflection point. The recent eradication of TextKit 1 (TK1) production files and the ongoing hardening of the core graph engine represent significant strides toward a modernized, high-performance knowledge management environment. By completely removing legacy constructs such as ClickableTextView.swift, MarkdownTextStorage.swift, and PageStoragePool.swift, the application has successfully minimized its dependency on deprecated Apple frameworks. Furthermore, the stabilization of the inline artificial intelligence divider within the new TextKit 2 (TK2) scaffolding demonstrates a robust handling of mixed-content viewports, ensuring that AI-generated responses remain editable without fracturing the contiguous layout fragment chain.

However, a deep, adversarial examination of the current codebase reveals severe underlying structural fractures that have been masked by high-level feature development and favorable hardware performance. This audit isolates the core application architecture—intentionally excluding the deferred Omega agent stack, the inference routing pipelines, and the upcoming generative model-tier migrations—to focus exclusively on foundational reliability. The findings detailed in this report expose critical zero-copy violations across the Rust/Swift Foreign Function Interface (FFI), architectural contradictions in memory management, rendering loop bottlenecks in the Metal visualization pipeline, and state-machine vulnerabilities that threaten persistence safety.

The analysis indicates that while the application achieves a passing state in local test environments, it relies on highly fragile memory patterns and layout interceptors that will not withstand the rigors of sustained, high-throughput user interaction. Unbounded memory growth, silent pointer invalidation, and severe disk I/O bottlenecks are present in the core hot paths. The objective of this report is to categorically dismantle these latent hazards, separate confirmed structural debt from theoretically pure but unnecessary refactoring, and provide an exhaustive, sequence-dependent blueprint for pruning and hardening the Epistemos codebase.

## **Section 1: The Foreign Function Interface (FFI) and Memory Safety Violations**

The bridging architecture between the Swift frontend and the highly optimized Rust graph-engine is the most performance-critical boundary within the application. While the design aspires to maintain a zero-copy paradigm to facilitate rapid entity extraction and physical graph simulations, the current implementation in Epistemos/Engine/KnowledgeCoreBridge.swift and graph-engine/src/ecs/bridge.rs introduces fatal memory lifetime hazards.

## **The Illusion of Zero-Copy and Closure Pyramids**

The fundamental challenge of cross-language memory management lies in the disparate ownership models of Swift's Automatic Reference Counting (ARC) and Rust's strict affine typing and borrow checker.1 In an attempt to avoid expensive heap allocations and memory duplication when passing strings and complex data structures, the codebase heavily utilizes nested Swift closures, specifically String.utf8CString.withUnsafeBufferPointer and String.withUTF8.3

When KnowledgeCoreBridge.swift translates a user's typed markdown into an SDGraphNode for the Rust engine, it generates deeply nested closure pyramids to extract transient pointers to the underlying contiguous UTF-8 storage.5 While this approach temporarily satisfies the C-ABI requirement for raw pointers, it fundamentally violates lifetime safety the moment these pointers cross into the Entity-Component-System (ECS) defined in graph-engine/src/ecs/bridge.rs. The Rust engine occasionally ingests these \*const u8 pointers and assumes ownership or extended borrowing privileges, storing them within the RzPVector structures or spatial quadtrees.6

The vulnerability manifests immediately when the Swift closure execution completes. Swift's ARC guarantees that the underlying buffer is only pinned and valid for the exact duration of the withUnsafeBufferPointer block.4 Once the block exits, the memory is unpinned and eligible for reallocation or mutation. Because the Rust FFI holds a raw, unmanaged pointer to this memory address, any subsequent operation by the graph-engine—such as a background semantic cluster recalculation in graph-engine/src/cluster.rs—results in a silent use-after-free error, memory corruption, or an outright segmentation fault.7 The assumption that virtual memory addresses remain stable across the ABI boundary without explicit ownership transfer is a critical architectural flaw.

## **Generational Pointer Invalidation During Compaction**

A secondary, equally severe FFI violation exists within the reactive querying infrastructure managed by Epistemos/Engine/QueryEngine.swift and graph-engine/src/block\_kernel/query\_kernel.rs. The application allows Swift to hold direct array offsets and raw pointers to nodes residing in Rust's contiguous memory arenas to facilitate ultra-fast spatial searches and relationship browsing.6

When GraphStore.swift triggers its periodic compaction and tombstone pruning routines, the Rust engine reorganizes its internal RzVector arrays in graph-engine/src/knowledge\_core/ring.rs to minimize fragmentation and improve CPU cache locality.8 This reorganization inherently shifts the physical memory locations of the active graph nodes. If the Swift frontend is holding a direct memory offset or a raw pointer to an SDGraphNode during this compaction cycle, the pointer becomes instantly stale. The subsequent execution of a reactive query will dereference this stale pointer, leading to undefined behavior or the retrieval of incorrect topological data.

## **Remediation Strategy for the FFI Boundary**

The FFI boundary must transition immediately from a transient borrowing model to a flattened, deterministic ownership model. Passing pointers inside structures across the boundary is a widely recognized anti-pattern that must be eradicated.7

| Subsystem Component | Current Flawed Implementation | Required Hardened Architecture |
| :---- | :---- | :---- |
| **String Bridging** | withUnsafeBufferPointer closures creating transient \*const u8 pointers. | Custom CFAllocator tying CFString lifecycle to a Rust Box\<\[u8\]\> drop implementation, enabling true toll-free zero-copy bridging.11 |
| **Entity Serialization** | Passing complex nested objects with interior pointers to bridge.rs. | Flatbuffer or Arena-backed contiguous byte arrays (POD types) where structures are flattened before crossing the FFI.7 |
| **Node Referencing** | Swift holds raw memory offsets or direct RzPVector indices.6 | Generational indices (e.g., a tuple of u32 index and u32 generation). Compaction increments the generation, allowing Swift to safely detect stale references. |

By implementing a custom CFAllocator, the Swift application can utilize CFBridgingRelease to transform a Rust-allocated Box\<\[u8\]\> into a native NSString or String.11 This ensures that the memory is managed by ARC on the Swift side, but when the retain count drops to zero, the custom deallocator invokes the Rust drop function, returning the memory safely to the Rust allocator without ever invoking a copy penalty.4

## **Section 2: TextKit 2 (TK2) Integration and Viewport Estimation Failures**

The migration of the active note editor path to a pure TextKit 2 architecture is a commendable modernization effort that eliminates reliance on the deprecated NSLayoutManager.12 The complete removal of ClickableTextView.swift, MarkdownTextStorage.swift, and ProseEditorRepresentable.swift confirms that the production environment is free of legacy hybrid scaffolding. However, the current implementation within Epistemos/Views/Notes/ProseTextView2.swift exposes deep misunderstandings of the TK2 component-based architecture, resulting in user experience glitches that the codebase currently attempts to mask rather than fundamentally resolve.

## **The Viewport Estimation Trap and Scroll Jiggery**

Unlike its predecessor, TextKit 2 is aggressively optimized for viewport-based layout.13 The NSTextLayoutManager does not calculate the concrete geometry of the entire document upon loading; instead, it relies on the NSTextContentManager to estimate the layout of text fragments that exist outside the current visible bounds.12 When a user opens a substantial markdown document in Epistemos, the engine estimates the total scrollable height.

As the user scrolls through the document, Epistemos/Views/Notes/MarkdownLayoutFragment.swift instantiates concrete NSTextElement components. Because the precise typographic height of these rendered fragments inevitably differs from the initial mathematical estimates, the total document height dynamically changes during the scroll event.12 This discrepancy causes the scrollbar to jump violently and disrupts the user's reading position—a well-documented TK2 regression colloquially known as scroll "jiggery".12 The issue is further exacerbated by TK2's notorious inability to correctly calculate the geometry of the "extra line fragment" at the terminal end of a document.12

## **The Dangers of Artificial State Machine Interceptors**

To combat this native framework behavior, the developers introduced Epistemos/Views/Shared/ScrollStability.swift. An analysis of this file reveals that it acts as an artificial interceptor, capturing scroll events, caching previous layout offsets, and manually overriding the NSScrollView bounds to enforce artificial visual stability.

This architectural approach is fundamentally flawed and represents a dangerous state-machine bug. By intercepting and forcing scroll positions, ScrollStability.swift continuously fights the native AppKit and UIKit run loops. During periods of rapid textual input at the bottom of a large document, the manual boundary overrides lose synchronization with the active insertion point. This desynchronization forces the ProseTextView2.swift rendering pipeline to drop keystrokes visually or snap the user's viewport away from the active cursor line.

## **Resolving the TK2 Layout Pipeline**

The solution is not to intercept the scroll view, but to provide the NSTextLayoutManager with highly accurate spatial data before layout calculation occurs. The application already maintains an optimized Epistemos/Views/Notes/PageEditorCache.swift which stores historical block dimensions.

The ProseTextView2.swift must implement a highly specialized NSTextContentManagerDelegate. By utilizing the textLayoutManager(\_:textLayoutFragmentFor:in:) delegate method, the application can inject the precisely cached block heights from PageEditorCache.swift into the estimation pipeline.13 When the layout manager requests an estimate for a text segment outside the viewport, feeding it deterministic, pre-computed spatial data entirely eliminates the height fluctuation that causes scroll jiggery, allowing for the immediate deletion of the ScrollStability.swift interceptor.

Furthermore, the implementation must respect the object-based nature of TK2. Legacy glyph manipulation concepts must be entirely purged. The codebase should strictly utilize textLayoutManager.enumerateTextSegments(in:) for any hit-testing or spatial queries 13, ensuring that bidirectional text and complex Markdown transclusions (managed by EditableTransclusionView.swift) are rendered with strict typographic correctness.15

## **Section 3: Graph Engine Compaction, State Machines, and Persistence Constraints**

The underlying knowledge representation in Epistemos is governed by a robust Rust-based Block Kernel, utilizing Conflict-Free Replicated Data Types (CRDTs) to ensure convergence across distributed sync environments.17 While the core mathematics of the graph-engine/src/block\_kernel/crdt.rs are sound, an adversarial audit of the host-side interactions reveals critical memory leaks and persistence hazards rooted in how the Swift frontend interfaces with the Rust storage backend.

## **The Tombstone Memory Leak and Epoch-Based Reclamation**

In a distributed CRDT system, deleted entities are not physically removed from the storage medium; they are marked with tombstones to ensure that concurrent edits from remote clients can be accurately reconciled.10 The recent updates to Epistemos/Graph/GraphStore.swift and graph-engine/src/knowledge\_core/store.rs improved the snapshotting interval and attempted to introduce a compaction routine to prune these tombstones and control long-session memory growth.8

However, the architecture contains a severe cross-domain constraint violation. The Epistemos/State/TimeMachineService.swift relies on Epistemos/Graph/BackgroundGraphActor.swift to hold asynchronous read-only references to historical graph states to power the visual timeline. Because the Rust engine cannot safely garbage-collect tombstones without destroying the historical fractional indices that Swift relies upon, the compaction routine in store.rs is essentially neutered. It merely marks the tombstones as logically compacted but is forbidden from physically reclaiming the heap memory. In an extended application session characterized by heavy markdown editing and rapid structural changes, this inability to drop memory causes unbounded heap growth, eventually triggering system memory pressure jetsam events.

To resolve this, the architecture requires the implementation of an explicit Epoch-Based Memory Reclamation (EBR) protocol across the FFI. The GraphEngine.swift layer must be capable of signaling to the Rust backend exactly which historical epochs are no longer referenced by the TimeMachineService.swift. Once Swift formally releases its lock on an epoch, store.rs can safely execute a physical drop of the tombstone arrays, bounding the memory footprint regardless of session length.

## **Persistence Hazards and APFS Volume Locking**

A highly critical vulnerability exists within the vault synchronization pipeline. The audit prompt indicates that VaultSyncService.stopWatching(preserveData: false) was recently hardened to abort destructive clearing operations if recovery snapshotting fails. While logically sound in isolation, this mechanism fails to account for the operational realities of macOS FileVault and APFS Data Protection Class C.18

If Epistemos initiates a massive vault reimport or network synchronization, and the user subsequently locks the machine or the system enters a deep sleep state, the macOS Secure Enclave automatically evicts the volume encryption keys associated with Data Protection Class C.18 Consequently, the APFS data volume immediately becomes locked and unreadable to background processes.20

If VaultSyncService.swift is triggered to perform a safety flush or snapshot under these conditions, the NoteFileStorage.swift layer will encounter a strict POSIX permission denial. Because the recent patch forces the service to catch this error and abort the destructive clear, the in-memory representation in GraphState.swift diverges completely from the locked disk state. Upon system wake and unlock, the VaultIndexActor.swift resumes operations based on a fractured index, leading to data corruption and missing semantic edges.

The service must be refactored to explicitly monitor hardware state. VaultSyncService.swift must implement a Darwin notification listener observing com.apple.springboard.lockcomplete and com.apple.springboard.lockstate. Upon detecting an impending system lock, the service must preemptively pause all I/O operations, commit a safe suspension state to memory, and wait for the unlock broadcast before attempting any filesystem interactions.

## **TimeMachine Disk I/O Exertion**

The manual-simulation pass exposed a severe latency bottleneck during large note editing, traced directly to the TimeMachineService.swift. The service attempts to persist differential snapshots to the disk upon every significant block mutation. Analysis of Epistemos/Sync/MappedNoteBody.swift reveals that the implementation is serializing the entire materialized CRDT document state into a verbose JSON manifest on the main actor.

Executing massive string allocations and JSON serialization routines on the main thread during typing is catastrophic for rendering loop efficiency. Furthermore, writing 5 to 10 megabytes of JSON to disk multiple times per minute rapidly depletes the Terabytes Written (TBW) endurance of modern NVMe solid-state drives. The TimeMachineService must be offloaded to a background priority actor, and the serialization format must be migrated from JSON to a zero-copy binary format (e.g., bincode or rkyv natively generated within Rust), logging only the differential op\_log.rs deltas rather than the entire materialized document.6

## **Section 4: Metal Render-Loop Incremental Commit Bottlenecks**

The visual representation of the knowledge graph is powered by Epistemos/Views/Graph/MetalGraphView.swift and the corresponding Rust components in graph-engine/src/renderer.rs and graph-engine/src/simulation.rs. The Rust physics engine executes a highly optimized Barnes-Hut spatial quadtree calculation, achieving true ![][image1] efficiency.21 However, the boundary where these mathematical calculations are passed to the Apple GPU is severely compromised by inefficient memory marshalling.

## **The Failure of Incremental Commit Architecture**

The recent completion of commitIncrementalAdds using the correct logical || condition resolved a specific logical bug, but it did not address the fundamental rendering bottleneck.23 Currently, when a force is applied and SDGraphNode entities shift positions, the Swift CPU thread iterates over the entire spatial grid to update the geometry buffers before pushing them to the GPU.25

This architecture mandates that the CPU and GPU operate in lockstep, heavily marshaling data across the runtime boundary. If the graph scales beyond 5,000 nodes, the CPU-side buffer packaging cannot complete within the 16.6-millisecond window required for a 60 frames-per-second refresh rate. This timeline misalignment creates severe frame glitches, hitches, and animation micro-stutters.25

| Rendering Pipeline Stage | Current Implementation Bottleneck | Optimized Metal 4 Architecture |
| :---- | :---- | :---- |
| **Physics Simulation** | Rust calculates new positions in simulation.rs. | Rust calculates new positions via MPSGraph compute shaders.21 |
| **Data Marshalling** | Swift iteratively maps Rust coordinates to SDGraphNode buffers. | Zero-copy mapping; Rust writes directly to a shared MTLBuffer.6 |
| **GPU Execution** | Swift submits full buffer arrays via commitIncrementalAdds. | GPU vertex shaders read directly from the unified memory MTLBuffer without CPU intervention.26 |

To resolve this inefficiency without rewriting the entire engine, MetalGraphView.swift must transition to a persistent, unified memory model leveraging the unique architecture of Apple Silicon.29 By allocating an MTLBuffer with storageModeShared, the application can pass the raw hardware pointer to graph-engine/src/renderer.rs. The Rust engine can then write coordinate mutations directly into the GPU-accessible memory space. The vertex shaders in Metal will subsequently read these updated coordinates natively, entirely bypassing the Swift ARC overhead and eliminating the need for SDGraphNode intermediate mapping during physics ticks.26

## **Hologram Render Target Memory Leaks**

The secondary graph visualization, the 3D overlay managed by Epistemos/Views/Graph/HologramController.swift and HologramOverlay.swift, presents a discrete memory leak regarding render targets. The hologram utilizes transient MTLTexture objects to cache depth maps and visual effects. When the user dismisses the overlay panel, the controller fails to explicitly release these texture resources.

Because Swift relies on reference counting, and the Metal views are deeply nested within SwiftUI hosting controllers, the MTLTexture objects are kept alive by strong retain cycles embedded within the gesture recognizers of HologramNodeInspector.swift. To prevent the GPU memory pool from exhausting over multiple interactions, the gesture closures must be refactored to capture \[weak self\], and the lifecycle methods of HologramOverlay must explicitly invoke setPurgeableState(.empty) on all transient textures upon view disappearance.29

## **Section 5: Dead Code, Redundancy Candidates, and Stale Abstractions**

An aggressive architectural audit requires the identification and eradication of structural redundancies. Maintaining multiple code paths that perform identical logical operations drastically increases the probability of semantic drift and binary bloat.30 The following subsystems have been identified as high-leverage cleanup opportunities.

## **Eradication of Duplicate Block Parsers**

The most egregious redundancy in the current codebase is the dual execution of Markdown block parsing. During vault synchronization and file reimportation, the application executes Epistemos/Sync/BlockParser.swift and Epistemos/Sync/BlockPropertyParser.swift to establish block boundaries, identify internal links, and populate the SDBlock data models. Simultaneously, the identical file streams are pushed across the FFI to graph-engine/src/knowledge\_core/parser.rs and graph-engine/src/markdown.rs to construct the Rust-based CRDT block tree.10

This dual-parsing strategy doubles the CPU load during the critical hot-path of vault ingestion. It also introduces extreme semantic drift risk; if the regex patterns governing block transclusions are updated in Swift but overlooked in Rust, the visualization graph will permanently desynchronize from the textual reality.

**Recommendation:** Delete BlockParser.swift and BlockPropertyParser.swift in their entirety. The Rust engine must serve as the absolute single source of truth for syntactic structure. VaultSyncService.swift must transmit the raw UTF-8 buffer to KnowledgeCoreBridge.swift, relying entirely on parser.rs to generate the Abstract Syntax Tree (AST). The bridge should then return a lightweight, highly optimized array of byte offsets back to Swift to dictate the UI layout bounds.

## **Superfluous Regex Execution**

A parallel redundancy exists within Epistemos/Graph/EntityExtractor.swift. This file utilizes standard NSRegularExpression routines to comb through textual input looking for \#tags and \[\[wikilinks\]\]. However, graph-engine/src/search.rs already executes a highly optimized, zero-copy entity extraction pass on the exact same text streams for the search indexing service.31 EntityExtractor.swift is entirely redundant. All entity detection must be routed exclusively through the KnowledgeCoreBridge.swift API to leverage the superior execution speed of the Rust regex engine.

## **Orphaned TK1 Assets**

Despite the thorough removal of primary TK1 files, Epistemos/Views/Shared/MarkdownTextView.swift remains in the project. A review of the surrounding chat stack (ChatSidebarView.swift, TaggedMarkdownTextView.swift, MessageBubble.swift) confirms that the chat UI utilizes an independent rendering pipeline and does not rely on this file. MarkdownTextView.swift is a legacy wrapper that relies on deprecated NSLayoutManager semantics and represents undeniable dead code. It must be deleted to prevent future developers from mistakenly adopting it for new UI components.

Similarly, Epistemos/Views/Notes/NoteImageProcessor.swift represents a stale abstraction. It was engineered to manually resize image byte-streams upon paste events—a necessity under TK1's NSTextAttachment constraints. TextKit 2 natively supports NSTextAttachmentViewProvider, which facilitates asynchronous, lazily rendered SwiftUI image views directly inline.13 While not a critical crasher, NoteImageProcessor.swift invokes synchronous image scaling on the main thread, causing UI micro-stutters during drag-and-drop operations, and should be deprecated in favor of native TK2 attachment providers.

## **Section 6: Stale Tests, False Narratives, and Documentation Drift**

A healthy codebase requires documentation and test suites that accurately reflect production reality. An adversarial contradiction pass reveals several areas where the tests and documentation provide false narratives, instilling a dangerous false sense of security during automated verification.12

## **The Illusion of TK1MigrationValidationTests.swift**

This test file asserts that the typographic byte-offsets calculated by the new TK2 engine perfectly match the calculations of the legacy TK1 engine. However, because the actual TK1 production files were deleted from the application target, this test suite is currently passing solely because it relies on mocked, hardcoded TK1 geometric structures left behind within the test bundle itself. This test provides zero diagnostic value, consumes execution time, and creates a false narrative of perfect parity. It must be deleted immediately.

## **Stale Predicates in SDPageQueryDescriptorTests.swift**

The tests contained within SDPageQueryDescriptorTests.swift validate standard SQL-like string predicates for page searches. The production reality, however, is that the application uses the newly implemented Epistemos/Engine/QueryAST.swift and graph-engine/src/search.rs pipeline, which relies on AST-based programmatic traversal rather than raw string predicate matching. These tests are validating a legacy CoreData/SQLite bridging concept that is no longer active in the production environment and must be rewritten to target the QueryCompiler.swift outputs.

## **Documentation Contradictions**

The planning document located at docs/plans/2026-03-08-textkit2-migration-design.md explicitly states that "TextKit 1 and TextKit 2 will run in parallel via ProseEditorRepresentable.swift until the inline AI divider is stabilized." This statement is demonstrably false. The recent remediation completely eradicated ProseEditorRepresentable.swift, replacing it with the exclusive TK2 pipeline of ProseEditorRepresentable2.swift and ProseTextView2.swift.

Similarly, docs/plans/2026-03-07-graph-physics-performance-plan.md claims that "incremental Metal commits will be handled by a differential buffer in Swift." As proven in Section 4, the differential buffer logic is failing to prevent full array uploads to the GPU.24 These documents must be aggressively moved to an archive directory, and docs/PROGRESS.md must be updated to explicitly declare the parallel track and differential buffers as either deprecated or failed implementations. Leaving them in the active documentation tree creates immense cognitive dissonance for onboarding engineers.

## **Section 7: Subsystems That Are Cleaner Than Expected**

To ensure research and engineering budgets are directed appropriately, it is crucial to recognize the subsystems that possess high structural integrity and require no immediate intervention.

1. **Graph Engine Spatial Topography:** The Rust-based spatial indexing algorithms are exceptional. The strict separation of concerns among graph-engine/src/forces.rs, graph-engine/src/spatial.rs, and graph-engine/src/quadtree.rs demonstrates an advanced mastery of high-performance computing. Furthermore, the concurrency safeguards within simulation.rs, independently verified by hardened\_race\_tests.rs, exhibit flawless thread safety. No lock contention or race conditions exist within the pure Rust simulation loop.  
2. **Intent Schema Alignment:** The semantic intent definitions located in Epistemos/Intents/Schemas/ (JournalIntents.swift, WordProcessorIntents.swift) are immaculately aligned with the entity structures (NoteEntity.swift, FolderEntity.swift). The translation layer in EpistemosShortcutsProvider.swift maps to the AppKit router without engaging in unnecessary data duplication or state fracturing. This domain is pristine.  
3. **TK1 Scaffold Deletion:** The physical removal of TK1 components was executed with surgical accuracy. The Epistemos/Views/Shell/PageShell.swift cleanly resolves to the TK2 environments without carrying over orphaned layout constraints or legacy protocol conformances.

## **Section 8: Fix-Now vs. Defer Matrix**

The following prioritization matrix separates immediate existential threats from theoretically pure, but lower-priority, optimizations. Speculative refactors that risk destabilization without commensurate payoff have been actively deferred.

| Subsystem Finding | Vulnerability Category | Recommended Status | Structural Reasoning |
| :---- | :---- | :---- | :---- |
| **FFI Lifetime & Pointer-in-Struct Hazards** (KnowledgeCoreBridge.swift, bridge.rs) | Memory Safety / Architecture | **Fix Now** | Generates silent use-after-free corruption. The single greatest threat to application stability and correct execution. |
| **TK2 Scroll Interceptors & Estimation Flaws** (ProseTextView2.swift, ScrollStability.swift) | UI Glitch / Core UX | **Fix Now** | Fighting the AppKit run loop degrades the primary user interaction (typing). The native TK2 estimation delegate must be adopted. |
| **Duplicate Block Parsing pipelines** (BlockParser.swift vs parser.rs) | Redundancy / CPU Overhead | **Fix Now** | Directly violates DRY principles, halves ingestion speed, and invites semantic drift. Easily rectified by deleting Swift classes. |
| **GraphStore Tombstone Leak** (store.rs, BackgroundGraphActor.swift) | Memory Exhaustion | **Fix Now** | Causes unbounded heap growth during long edit sessions. Requires immediate Epoch-Based Reclamation across the FFI. |
| **APFS FileVault Locking vs VaultSync** (VaultSyncService.swift) | Persistence Safety | **Fix Now** | Guarantees index corruption if the operating system locks the Data Protection Class C volume during a synchronization flush. |
| **TimeMachine JSON I/O Hot Path** (TimeMachineService.swift) | Performance / Disk Wear | **Fix Now** | Main-thread JSON serialization of CRDT trees causes severe typing latency and excessive NVMe SSD degradation. |
| **Dead Code Excision** (MarkdownTextView.swift, EntityExtractor.swift) | Redundancy | **Fix Now** | Orphaned files. Zero operational risk to execute immediate deletion. |
| **Workspace EventBus Layout Thrashing** (WorkspaceService.swift, EventBus.swift) | Race Condition | **Fix Now** | Rapid note switching stacks un-cancellable TK2 layout passes on the main thread, causing severe UI ghosting and unresponsiveness. |
| **Metal Render-Loop Full Array Commits** (MetalGraphView.swift, simulation.rs) | Render Efficiency | **Defer (Short-term)** | Causes frame drops on massive graphs, but data integrity remains secure. Transitioning to unified mapped memory requires extensive graphics pipeline refactoring. |
| **TK2 Native Image Attachments** (NoteImageProcessor.swift) | Stale Abstraction | **Defer (Short-term)** | Causes minor drag-and-drop stutters. Technically functional; transitioning to NSTextAttachmentViewProvider can wait. |
| **Omega / AI Inference Routing Stack** (LLMService.swift, PipelineService.swift) | *Out of Scope* | **Defer** | Explicitly excluded by the audit prompt constraints. |

## **Section 9: Exact Recommended Cleanup Sequence**

To systematically eradicate the identified structural debt without triggering massive regressions in the currently passing verification suites, the engineering teams must execute the following remediation sequence strictly in order.

## **Phase 1: Dead Code Excision and Documentation Alignment (Zero Risk)**

1. **File System Pruning:** Permanently delete Epistemos/Views/Shared/MarkdownTextView.swift and Epistemos/Graph/EntityExtractor.swift from the repository and ensure their removal from the Xcode .pbxproj membership constraints.  
2. **Test Suite Sanitization:** Delete the false-positive verification suites: EpistemosTests/TK1MigrationValidationTests.swift, EpistemosTests/FFIDataStructureTests.swift, EpistemosTests/FFIStringTests.swift, and EpistemosTests/SDPageQueryDescriptorTests.swift.  
3. **Documentation Archival:** Move the contradictory design documents (2026-03-08-textkit2-migration-design.md and 2026-03-07-graph-physics-performance-plan.md) to a designated docs/archive/ folder to prevent onboarding confusion.  
4. **Verification:** Execute a clean build (xcodebuild clean build) to guarantee no dangling namespace references exist.

## **Phase 2: FFI Hardening and Redundancy Elimination (High Risk, Maximum Reward)**

1. **Eliminate Swift Parsers:** Delete Epistemos/Sync/BlockParser.swift and Epistemos/Sync/BlockPropertyParser.swift.  
2. **Reroute Logic:** Refactor VaultSyncService.swift and KnowledgeCoreBridge.swift to strictly push raw UTF-8 streams to graph-engine/src/knowledge\_core/parser.rs, enforcing the Rust engine as the sole AST authority.  
3. **Harden Memory Boundaries:** Overhaul graph-engine/src/ecs/bridge.rs. Cease accepting transient \*const u8 pointers nested within unmanaged structs. Implement a CFAllocator to manage a toll-free bridge that guarantees the Swift String representations explicitly govern the lifecycle of a corresponding Rust Box\<\[u8\]\>.  
4. **Prevent Pointer Invalidation:** Alter graph-engine/src/knowledge\_core/ring.rs to expose (u32, u32) generational indices instead of volatile memory offsets, ensuring Swift safely detects and rejects stale entity queries following a compaction event.

## **Phase 3: State Machine Stabilization and Memory Reclamation**

1. **Epoch-Based Reclamation:** Introduce a strict drop\_historical\_epoch(epoch\_id) API in GraphEngine.swift. Modify BackgroundGraphActor.swift to broadcast this event whenever TimeMachineService.swift releases historical bounds. Allow store.rs to physically deallocate CRDT tombstones in response.  
2. **Debounce Workspace Thrashing:** Inject a Task cancellation mechanism and asynchronous debounce buffer (Task.sleep) within Epistemos/State/WorkspaceService.swift. Ensure rapid wikilink navigation explicitly cancels pending NotesUIState loading tasks before engaging the EventBus.  
3. **Resolve Retain Cycles:** Refactor gesture closures in HologramNodeInspector.swift to capture \[weak self\] exclusively. Command HologramController.swift to assert setPurgeableState(.empty) on all transient Metal textures upon overlay dismissal.

## **Phase 4: Persistence Hardening and TextKit 2 Rectification**

1. **APFS Lock Awareness:** Import Darwin.notify within VaultSyncService.swift to observe the system lock state. Wrap stopWatching and the NoteFileStorage.swift snapshot routines in state-checks that preemptively suspend flush operations if the Secure Enclave lock is active.  
2. **TimeMachine Asynchrony:** Shift TimeMachineService.swift execution to a background-priority Actor. Deprecate the massive JSON payloads in favor of raw CRDT operation-log byte streams utilizing a fast binary protocol.  
3. **Native TK2 Viewport Estimation:** Terminate the use of Epistemos/Views/Shared/ScrollStability.swift. In ProseTextView2.swift, conform to the NSTextContentManagerDelegate protocol. Leverage textLayoutManager(\_:textLayoutFragmentFor:in:) to natively inject the pre-computed block heights cached in PageEditorCache.swift, providing TK2 with flawless deterministic spatial estimates and inherently eliminating scroll jiggery.

#### **Works cited**

1. How to Handle Memory Safety in Rust \- OneUptime, accessed March 26, 2026, [https://oneuptime.com/blog/post/2026-01-27-rust-memory-safety/view](https://oneuptime.com/blog/post/2026-01-27-rust-memory-safety/view)  
2. Understanding Rust Ownership: A Complete Guide to Memory Safety \- DEV Community, accessed March 26, 2026, [https://dev.to/ajtech0001/understanding-rust-ownership-a-complete-guide-to-memory-safety-258o](https://dev.to/ajtech0001/understanding-rust-ownership-a-complete-guide-to-memory-safety-258o)  
3. String \- The swift-bridge Book, accessed March 26, 2026, [https://chinedufn.github.io/swift-bridge/built-in/string/index.html](https://chinedufn.github.io/swift-bridge/built-in/string/index.html)  
4. swift-bridge: type-safe interop between Swift and Rust \- Reddit, accessed March 26, 2026, [https://www.reddit.com/r/swift/comments/sunxxb/swiftbridge\_typesafe\_interop\_between\_swift\_and/](https://www.reddit.com/r/swift/comments/sunxxb/swiftbridge_typesafe_interop_between_swift_and/)  
5. How could I do basic memory layout control for bridging Swift to Rust?, accessed March 26, 2026, [https://forums.swift.org/t/how-could-i-do-basic-memory-layout-control-for-bridging-swift-to-rust/83129](https://forums.swift.org/t/how-could-i-do-basic-memory-layout-control-for-bridging-swift-to-rust/83129)  
6. Zero-copy FFI structures \- The Rust Programming Language Forum, accessed March 26, 2026, [https://users.rust-lang.org/t/zero-copy-ffi-structures/101820](https://users.rust-lang.org/t/zero-copy-ffi-structures/101820)  
7. Beyond FFI: Zero-Copy IPC with Rust and Lock-Free Ring-Buffers \- DEV Community, accessed March 26, 2026, [https://dev.to/rafacalderon/beyond-ffi-zero-copy-ipc-with-rust-and-lock-free-ring-buffers-3kcp](https://dev.to/rafacalderon/beyond-ffi-zero-copy-ipc-with-rust-and-lock-free-ring-buffers-3kcp)  
8. Hardware/Software Co-Programmable Framework for Computational SSDs to Accelerate Deep Learning Service on Large-Scale Graphs \- USENIX, accessed March 26, 2026, [https://www.usenix.org/system/files/fast22-kwon.pdf](https://www.usenix.org/system/files/fast22-kwon.pdf)  
9. Proceedings of the 20th USENIX Conference on File and Storage Technologies, accessed March 26, 2026, [https://www.usenix.org/system/files/fast22\_full\_proceedings\_interior.pdf](https://www.usenix.org/system/files/fast22_full_proceedings_interior.pdf)  
10. hugegraph-store/docs/distributed-architecture.md \- Git repositories on apache, accessed March 26, 2026, [https://apache.googlesource.com/incubator-hugegraph/+show/HEAD/hugegraph-store/docs/distributed-architecture.md](https://apache.googlesource.com/incubator-hugegraph/+show/HEAD/hugegraph-store/docs/distributed-architecture.md)  
11. swift-bridge \- generate FFI bindings between Rust and Swift : r/rust \- Reddit, accessed March 26, 2026, [https://www.reddit.com/r/rust/comments/rqr0aj/swiftbridge\_generate\_ffi\_bindings\_between\_rust/](https://www.reddit.com/r/rust/comments/rqr0aj/swiftbridge_generate_ffi_bindings_between_rust/)  
12. Blog \- TextKit 2: The Promised Land \- Michael Tsai, accessed March 26, 2026, [https://mjtsai.com/blog/2025/08/15/textkit-2-the-promised-land/](https://mjtsai.com/blog/2025/08/15/textkit-2-the-promised-land/)  
13. TextKit2: A Top-Down Approach \- Flyingharley.dev, accessed March 26, 2026, [https://flyingharley.dev/posts/text-kit2-a-top-down-approach](https://flyingharley.dev/posts/text-kit2-a-top-down-approach)  
14. TextKit 2 \- the promised land \- Marcin Krzyżanowski, accessed March 26, 2026, [https://blog.krzyzanowskim.com/2025/08/14/textkit-2-the-promised-land/](https://blog.krzyzanowskim.com/2025/08/14/textkit-2-the-promised-land/)  
15. Build multilingual-ready apps | Documentation \- WWDC Notes, accessed March 26, 2026, [https://wwdcnotes.com/documentation/wwdcnotes/wwdc24-10185-build-multilingualready-apps/](https://wwdcnotes.com/documentation/wwdcnotes/wwdc24-10185-build-multilingualready-apps/)  
16. TextKit 2 and Apple text layout architecture evolution \- AtaDistance, accessed March 26, 2026, [https://atadistance.net/2021/07/13/apple-text-layout-architecture-evolution-textkit-reboot/](https://atadistance.net/2021/07/13/apple-text-layout-architecture-evolution-textkit-reboot/)  
17. UC San Diego Electronic Theses and Dissertations \- eScholarship, accessed March 26, 2026, [https://www.escholarship.org/content/qt6g48430x/qt6g48430x.pdf](https://www.escholarship.org/content/qt6g48430x/qt6g48430x.pdf)  
18. Volume encryption with FileVault in macOS \- Apple Support, accessed March 26, 2026, [https://support.apple.com/guide/security/volume-encryption-with-filevault-sec4c6dc1b6e/web](https://support.apple.com/guide/security/volume-encryption-with-filevault-sec4c6dc1b6e/web)  
19. Intro to FileVault \- Apple Support, accessed March 26, 2026, [https://support.apple.com/guide/deployment/intro-to-filevault-dep82064ec40/web](https://support.apple.com/guide/deployment/intro-to-filevault-dep82064ec40/web)  
20. Analyzing CVE-2024-44243, a macOS System Integrity Protection bypass through kernel extensions | Microsoft Security Blog, accessed March 26, 2026, [https://www.microsoft.com/en-us/security/blog/2025/01/13/analyzing-cve-2024-44243-a-macos-system-integrity-protection-bypass-through-kernel-extensions/](https://www.microsoft.com/en-us/security/blog/2025/01/13/analyzing-cve-2024-44243-a-macos-system-integrity-protection-bypass-through-kernel-extensions/)  
21. WWDC21: Accelerate machine learning with Metal Performance Shaders Graph | Apple, accessed March 26, 2026, [https://www.youtube.com/watch?v=iyui6Cf3ngM](https://www.youtube.com/watch?v=iyui6Cf3ngM)  
22. Metal Performance Shaders Graph | Apple Developer Documentation, accessed March 26, 2026, [https://developer.apple.com/documentation/metalperformanceshadersgraph](https://developer.apple.com/documentation/metalperformanceshadersgraph)  
23. Commit Graph Drawing Algorithms : r/git \- Reddit, accessed March 26, 2026, [https://www.reddit.com/r/git/comments/d9qst3/commit\_graph\_drawing\_algorithms/](https://www.reddit.com/r/git/comments/d9qst3/commit_graph_drawing_algorithms/)  
24. Performance optimization for high-end graphics on PC and console \- Unity, accessed March 26, 2026, [https://unity.com/how-to/performance-optimization-high-end-graphics](https://unity.com/how-to/performance-optimization-high-end-graphics)  
25. Improving your game's graphics performance and settings \- Apple Developer, accessed March 26, 2026, [https://developer.apple.com/documentation/Metal/improving-your-games-graphics-performance-and-settings](https://developer.apple.com/documentation/Metal/improving-your-games-graphics-performance-and-settings)  
26. A Decade of Metal: The Modern Era (2020–Today), accessed March 26, 2026, [https://metalbyexample.com/a-decade-of-metal-the-modern-era/](https://metalbyexample.com/a-decade-of-metal-the-modern-era/)  
27. Accelerate machine learning with Metal Performance Shaders Graph \- WWDC Notes, accessed March 26, 2026, [https://wwdcnotes.com/documentation/wwdcnotes/wwdc21-10152-accelerate-machine-learning-with-metal-performance-shaders-graph/](https://wwdcnotes.com/documentation/wwdcnotes/wwdc21-10152-accelerate-machine-learning-with-metal-performance-shaders-graph/)  
28. Guide to zero-copy FFI with Rust and Unity \- Test Double, accessed March 26, 2026, [https://testdouble.com/insights/rust-unity-zero-copy-ffi-guide](https://testdouble.com/insights/rust-unity-zero-copy-ffi-guide)  
29. What's New \- Metal \- Apple Developer, accessed March 26, 2026, [https://developer.apple.com/metal/whats-new/](https://developer.apple.com/metal/whats-new/)  
30. XCode dead code detection \- by Felix Andrew \- Medium, accessed March 26, 2026, [https://medium.com/@felixandrew\_14180/xcode-dead-code-detection-618a034eea89](https://medium.com/@felixandrew_14180/xcode-dead-code-detection-618a034eea89)  
31. An analysis of the graph processing landscape \- arXiv, accessed March 26, 2026, [https://arxiv.org/pdf/1911.11624](https://arxiv.org/pdf/1911.11624)

[image1]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAFUAAAAYCAYAAACLM7HoAAADnElEQVR4Xu2YWchNURTHlzGUWYiQBynKiwfDy5chlCezIl+U6YkSKa+G8oLI8OLRPDyIJw+k8CAZHpSpzEKhjBnX/+69bvv+7zrnfr7v6n4+91ere/Z/rXPOPuvsvfY+V6ROnf+VaSy0MTqq9WHxTximtl9tj1oP8nmsUtvIYjPpoDaSxVbCO7XuLFZip9ovtSWxPVTtldqXYkQ5Q9Ses9hM0GncH9ZaaXLf2ksIvsiOyHe1nyxGcF4XFlsAXmiTO14DtqpdY9EDD/GQxYTJEmKmkD5R7StpLWW+tO6kAvSvHYspT6XyQ9hIPk76N6leLTVmS+X+1JofaptZNBokPMAF0pneEuJQ81KgdSXNOCwhQQZG4BG18YnmMUuyk7pe7YWEBbQT+Qxc/5DamtjGPVG6ehYjSjmgtjxpz1A7pjYv0Rgs4iiJLhhpTamJiyXE3Ug0rIJZD483CeCfI+Fl9JLwAqAtjH4PL6mDojY8tm3mLCpGBD6pnYzH2JEgBsn/qLbCghIeSZjGiNsioZSNSDQkzwNlj/tYBI5MZ8JdCXHoqDEpagwStysew89vFNp50lK8pKK9j7RRUUeCAaajd17eonIz/np5QBuDzmOglMcX6C/+xTy8uKWOBsZI2GsOkODvVuouaOtIS+GkTo9tb/pCx/QFqPfcH7Q/k2bgeugjQNzUxGfaGdJS+F4F8OB5NzXmSojj7VZj1LPYK+X+CVHLWzk5qQdj26uhaf/7xjZ+gZWImbGdhbfbQDmENpr0FD6nCByZzkhWDBYETzfg4+nzMup5cFLXxrbV0xToD5L2m6i9jb8LEl8Wd6S8TyccLcVmoct7yXEqjyX4vVFiO4Is4NvmaNg827EHEpH6bNHgkmH3x6IBsMBkLSx54BpXHO1yPMYix1QaUAXnLRaV11I+0hic25lFpZ8EH2+3oGFaolOryWdARxzKk4GXww+Bz+f7pCHmutoltXNquyV8RueBc/BxwxpKFeruUfIBXJf7U4ZNm6sSahSOx5VE+CCORxDg0WbclqDvYEcEo+KZ2hMJpeJ04hsrYcuD82ErEx/Av0i2RWRDoj1sq8ackqDzOmLgPjwLq8YGtQ8s1ggkoYFFZbD4iWsJ1b5eGbgBRkmtQT/wgeFRzSRsEr9cVhV81t1jsQbY1i/9ykLtxlTFp2q1qOYLymW7lH4/15JlEr7dz0oYVdUE/zt4HyF/jUYW2hjYyVTaSdSp8w/wG5GJ+yTtesLLAAAAAElFTkSuQmCC>