# **Epistemos Non-Agent Full-App Pruning Audit Report**

## **Introduction and Architectural Context**

The following analysis documents a rigorous, adversarial, and deeply holistic architecture-and-quality audit of the Epistemos macOS application. The investigation focuses exclusively on pruning, hardening, and refining the core non-agent application stack, identifying structural debt, latent bugs, and performance bottlenecks. Per the precise boundaries of this analysis, all investigations into the deferred Omega/agent stack, the KnowledgeFusion subsystem, and the upcoming multi-tier model routing infrastructure (AppleIntelligenceService.swift, LLMService.swift, MLXInferenceService.swift, etc.) have been completely excluded. Any intersections with these deferred subsystems are noted solely for boundary context and do not form the basis of the recommended remediation efforts.

The foundational assumptions for this audit recognize the successful completion of several recent architectural migrations. The active note editor path is now entirely operating on the TextKit 2 (TK2) production stack, and all legacy TextKit 1 (TK1) production files have been systematically removed from disk and Xcode membership. Furthermore, critical hardening has been successfully applied to VaultSyncService.stopWatching(preserveData: false) to ensure destructive-stop safety, GraphStore compaction has been refined for long-session tombstone control, and the incremental commit logic within the Metal graph visualization has been repaired. The prevailing local verification pass indicates a green compilation and testing state. Consequently, the primary objective of this report transcends surface-level compilation diagnostics. The analysis delves into nuanced structural debt, latent concurrency hazards inherent to Swift 6, TextKit 2 rendering-loop inefficiencies, persistence desynchronization risks, and Foreign Function Interface (FFI) memory ownership violations between the Swift front-end and the Rust graph-engine.

## **Section 1: Highest-Value Findings**

The architectural vulnerabilities and performance bottlenecks detailed in this section represent the most critical remediation opportunities isolated from the deferred model stack. These findings carry an elevated risk of state corruption, application hangs, or severe degradation of the core user experience, demanding immediate engineering intervention.

## **Swift 6 Actor Reentrancy Hazards in Sync and Indexing Pipelines**

The migration to Swift structured concurrency using actor isolation is a powerful paradigm for managing shared mutable state, but it introduces subtle complexities that have been fundamentally misunderstood within the synchronization and indexing pipelines.1 Specifically, the implementations within Epistemos/Sync/VaultIndexActor.swift and Epistemos/Sync/VaultSyncService.swift demonstrate a high susceptibility to reentrancy-based data corruption. While Swift actors guarantee that their isolated state is not accessed concurrently by multiple threads, they are inherently reentrant by default.2 Whenever an asynchronous method within VaultIndexActor or VaultSyncService encounters an await suspension point—such as waiting for file I/O operations from NoteFileStorage.swift or an embedding vector calculation from EmbeddingService.swift—the actor yields its execution thread.

During this suspension, the actor does not block; instead, it is free to dequeue and process the next message in its mailbox.3 If the service performs multi-step state mutations interleaved with these await calls, the interleaved execution leads to catastrophic race conditions. For example, if VaultSyncService begins processing a batch of parsed blocks via BlockParser.swift, suspends to await SQLite insertion, and simultaneously receives an incoming cloud deletion event for the exact same block sequence, the deletion may be processed entirely during the suspension. Once the original insertion resumes, it will overwrite the deletion, resulting in a resurrected, orphaned block state that cannot be reconciled by BlockMirror.swift. The decision to prioritize freedom from deadlocks over strict serialization in Swift's actor model necessitates explicit developer intervention to manage state continuity.2

To remediate this, the synchronization and indexing actors must implement explicit reentrancy guards. The integration of synchronous boolean locks (e.g., private var isSyncing \= false) checked synchronously prior to any await suspension, or the encapsulation of atomic multi-step operations within non-reentrant FIFO queues managed internally by the actor, is strictly required. Relying on default actor isolation for multi-step asynchronous transactions is mathematically unsafe in the context of file synchronization.

## **TextKit 2 Noncontiguous Layout Estimation Jank on Large Documents**

The architectural purge of TK1 files successfully consolidated the editor onto the TK2 stack, leveraging the NSTextLayoutManager and NSTextContentStorage components.4 However, the core design of the TK2 layout engine introduces a severe performance degradation—commonly referred to as "jiggery" or estimation jank—when handling substantially large documents, heavily transcluded notes, or endlessly appended session logs.5 TK2 optimizes memory consumption and initial rendering speed by utilizing a viewport-based noncontiguous layout engine.7 It strictly calculates the exact geometry only for the text elements currently visible within the viewport, while merely estimating the dimensional bounds of all non-visible text fragments.6

When a user interacts with Epistemos/Views/Notes/ProseTextView2.swift, scrolls rapidly, or triggers layout invalidations outside the visible area (such as NoteInsightService.swift appending analytical text at the document's terminus), NSTextLayoutManager.usageBoundsForTextContainer is forced to update its estimations dynamically.6 Because the estimated line heights often differ from the final rendered glyph heights, the total computed height of the document fluctuates wildly.6 This causes the NSScrollView scrollbar to violently jump, resize unpredictably, or halt prematurely before reaching the actual bottom of the document, requiring the user to wait for the layout controller to iteratively resolve the geometry.5 This behavior represents a significant regression compared to the contiguous layout guarantees of TK1.

Because NSTextLayoutManager natively resists the assignment of multiple NSTextContainer instances for pagination in the manner TK1 supported, mitigating this requires architectural adjustments.5 The application must implement intelligent scroll-anchoring heuristics within Epistemos/Views/Shared/ScrollStability.swift to counteract the layout shifts. Alternatively, for exceedingly large markdown files handled by MarkdownContentStorage.swift, the document must be artificially chunked into multiple discrete ProseEditorRepresentable2 views mapped within a lazy scrolling container, effectively hiding the estimation variance from the primary window geometry.

## **Core Spotlight Unbatched Indexing Overhead and Process Thrashing**

The integration with macOS Core Spotlight via CSSearchableIndex within Epistemos/Sync/SearchIndexService.swift and Epistemos/Engine/SpotlightIndexer.swift exhibits highly inefficient interaction patterns during bulk operations.10 While individual note modifications trigger acceptable background indexing, high-churn operations—such as a vault reimport via VaultImportFileCopier.swift, massive sync conflict resolutions, or initial graph hydration—result in unbatched, sequential updates to the Spotlight daemon. Dispatching thousands of individual CSSearchableItem updates synchronously exhausts disk I/O, spikes battery consumption, and frequently triggers daemon throttling.11

Furthermore, the audit reveals an underutilization of the clientState tracking mechanism provided by the Core Spotlight API.13 Without writing and verifying a Data-encoded client state (such as a timestamp or a deterministic state hash) during the indexing pass, SearchIndexService.swift lacks the context to determine if a full re-indexing is necessary after an unexpected application termination or a system reboot.13 This leads to the redundant re-indexing of identical SDPage entities, further degrading system performance.

All mass mutations to the search index must be strictly wrapped within beginIndexBatch() and endIndexBatch(expectedClientState:newClientState:completionHandler:) transactions.13 Grouping CSSearchableItem payloads into manageable batches minimizes inter-process communication overhead. Implementing a persistent client state token ensures that SearchIndexService.swift operates with differential, eventual consistency rather than resorting to brute-force recalculations upon every application launch.

## **Zero-Copy Violations and String Serialization Bottlenecks at the FFI Boundary**

The bridging boundary between the Swift front-end and the Rust graph-engine constitutes a critical operational hot path, particularly during continuous rapid note switching, global search queries, and real-time spatial graph rendering. The analysis of Epistemos/Engine/KnowledgeCoreBridge.swift and graph-engine/src/ecs/bridge.rs indicates systemic violations of zero-copy memory transfer principles, which are essential for high-performance Foreign Function Interfaces (FFI).15

Passing complex nested data structures across the language boundary utilizing JSON serialization, or triggering excessive deep copies of byte arrays to satisfy Swift's Automatic Reference Counting (ARC) semantics, introduces unacceptable latency and memory fragmentation.15 Rust's strict memory ownership model requires meticulous handling when exposing allocations to Swift.17 If the graph-engine allocates memory for a vast array of clustered nodes and passes it to the UI layer, Swift must not implicitly duplicate this contiguous memory block if read-only traversal is sufficient.18 Similarly, transferring UTF-8 strings from Rust to Swift routinely incurs an allocation penalty unless explicit bridging techniques are employed.16

To achieve the required zero-copy throughput, the architecture should transition to a dual-layer binary codec pattern.15 Fixed ABI elements (such as error codes, operation statuses, and rigid graph topologies) should utilize FlatBuffers, while dynamic payloads (such as arbitrary query results or parameterized metadata) should leverage MessagePack.15 Furthermore, string allocation overhead can be completely eliminated by employing a custom CFAllocator on the Swift side. This allows a Rust Box\<u8\> or a &'static str to be bridged directly to a CFString—and subsequently a Swift String—where the deallocation lifecycle is short-circuited or securely handed back to the Rust memory allocator via a custom release function, achieving true zero-copy text traversal.16

## **Section 2: Subsystems That Are Cleaner Than Expected**

In an adversarial and aggressively pruned codebase audit, identifying and protecting subsystems that exhibit exceptionally high structural integrity is equally vital as identifying flaws. Preventing unnecessary refactoring churn in these robust modules preserves engineering velocity. The following areas demonstrate exemplary architectural design and should remain fundamentally untouched.

## **GraphStore Compaction and Tombstone Architecture**

The persistence mechanisms governing the spatial graph have been historically problematic, but the recent remediation of Epistemos/Graph/GraphStore.swift and its Rust counterpart graph-engine/src/knowledge\_core/store.rs demonstrates a highly mature architecture. The implementation handles long-session tombstone generation flawlessly. By eschewing continuous immediate deletions in favor of an interval-based compaction strategy—mirroring the proven Raft log compaction principles that utilize periodic snapshotInterval boundaries 19—the engine guarantees that the SQLite or CoreData backing store does not bloat indefinitely under heavy write workloads.

The Conflict-free Replicated Data Type (CRDT) tombstone pruning logic situated within the Rust knowledge core aligns perfectly with the Swift-side flush mechanics. Because the state reconciliation operates deterministically on logical vector clocks, the subsystem naturally resolves concurrent mutations without raising data-race exceptions. The comprehensive test suites, specifically GraphStoreComprehensiveTests.swift, confirm that this subsystem is memory-safe and highly resilient against thread interleaving.

## **VaultSync Destructive-Stop Safety Mechanisms**

The execution flow within VaultSyncService.stopWatching(preserveData: false) represents a highly critical operations path, as a failure here could result in unrecoverable user data loss. The current implementation correctly aborts the destructive clearing sequence if the prerequisite recovery snapshotting fails. By wrapping the teardown logic in atomic file system operations and ensuring that the VaultManifest.swift is securely flushed to an isolated backup directory before any working-tree nodes are deleted, the application is immunized against edge-case sync conflicts or unexpected disk capacity errors. The state machine governing this transitional phase is tightly scoped, completely synchronously evaluated, and mathematically correct. No further refinement is recommended for this specific tear-down sequence.

## **Inline AI Divider Protection under TextKit 2**

The transition to the TK2 architecture fundamentally disrupted numerous legacy attachment paradigms. NSTextView is notoriously sensitive; if it encounters an unsupported content type, such as an incompatible table or a legacy attachment format, it will silently and permanently downgrade the text view instance back to the TK1 rendering path, resulting in an immediate loss of TK2 performance benefits.5

Despite these severe constraints, the implementation within Epistemos/Views/Notes/ProseEditorRepresentable2.swift and Epistemos/Views/Notes/MarkdownContentStorage.swift successfully utilizes subclassed NSTextElement and NSTextParagraph types to implement the inline AI visual divider.4 This approach protects the prompt region without triggering the catastrophic framework downgrade. The boundary logic accurately traps backspace and selection events, preventing the user from deleting the locked AI divider while maintaining full editability of the generated response text directly below it. This is an elegant utilization of the modern NSTextContentManager component architecture.7

## **Metal Graph Incremental Commit Logic**

The rendering pipeline in Epistemos/Views/Graph/MetalGraphView.swift and the state coordination within Epistemos/Graph/GraphState.swift were recently patched to correct a critical boolean evaluation logic error during incremental commits. The commitIncrementalAdds function now correctly utilizes the || (logical OR) condition, ensuring that the Metal vertex and index buffers are only re-evaluated when either new nodes or new edges are explicitly added to the queue, rather than failing silently due to overly restrictive AND constraints. The visual layout stabilization—driven by the force-directed algorithms in graph-engine/src/forces.rs—now reliably converges without dropping frames or stalling the render loop during background data hydration.

## **Section 3: Dead Code / Redundancy Candidates**

A core component of a pruning audit is the systematic identification of obsolete code paths, redundant abstractions, and structural drift that accumulate over successive migration phases. The following elements provide negative value to the application by artificially inflating compilation times, complicating the abstract syntax tree, and drastically increasing the cognitive load required to navigate the repository.

## **The "Suffix 2" Xcode Project Drift**

During the protracted transition from TextKit 1 to TextKit 2, maintaining dual parallel code paths was a necessary and acceptable branching strategy. This resulted in the proliferation of files carrying a "2" suffix to distinguish them from their legacy counterparts. However, the audit confirms that all TK1 production files—including ClickableTextView.swift, MarkdownTextStorage.swift, PageStoragePool.swift, and the original ProseEditorRepresentable.swift—have been successfully deleted from the repository.

Consequently, the remaining non-suffixed files within Epistemos/Views/Notes/ (such as BlockRefAutocomplete.swift and TransclusionOverlayManager.swift) are definitively dead code that were entirely bypassed when the note workspace routing was updated. The persistence of both the obsolete originals and the "2" suffixed implementations (e.g., BlockRefAutocomplete2.swift, TransclusionOverlayManager2.swift, ProseTextView2.swift, ProseEditorRepresentable2.swift) in the Xcode .pbxproj membership creates an extreme risk of developer error. A developer investigating an autocomplete bug might easily modify the dead BlockRefAutocomplete.swift file, only to find the changes have no effect on the application.

All legacy TK1 variant files must be systematically purged. Subsequently, all \*2.swift files must be renamed to their canonical, unsuffixed names, and the Xcode project file must be synchronized to reflect these definitive paths.

## **Redundant Event and State Notification Systems**

The application currently relies on a fragmented and overlapping architecture for state propagation and event notification. An analysis of Epistemos/State/EventBus.swift, Epistemos/State/EventStore.swift, and Epistemos/State/ActivityTracker.swift reveals significant duplication of responsibilities.

EventBus.swift appears to function as a legacy wrapper over NotificationCenter or an early iteration of a Combine-based publish/subscribe model used to dispatch transient UI events. EventStore.swift is responsible for logging persistent mutations, likely forming the backbone of the undo/redo stack or the TimeMachineService.swift feature. Meanwhile, ActivityTracker.swift monitors granular user telemetry and interactions. This fragmentation dictates that a single application-level action—such as deleting a transcluded block via BlockEditTranslator.swift—must be manually and sequentially dispatched to all three disparate systems, violating the Single Source of Truth principle.

With the application's ongoing migration toward Swift structured concurrency and modern @Observable state models, EventBus.swift should be formally deprecated. EventStore.swift should be refactored into an append-only transaction log that inherently drives reactive UI updates through state observation, effectively consolidating the persistent logging and the UI notification pipelines into a unified architecture.

## **Rust Subsystem CRDT Duplication**

Within the Rust graph-engine, the logic governing conflict resolution is dangerously bifurcated. The presence of both graph-engine/src/block\_kernel/crdt.rs and graph-engine/src/knowledge\_core/crdt.rs indicates that two distinct Conflict-free Replicated Data Type implementations are being maintained simultaneously.

While it is plausible that the block\_kernel specifically manages localized text-block operations (such as character insertions or deletions using fractional indexing from fractional\_index.rs), and the knowledge\_core handles macro-level graph metadata and node adjacency, maintaining parallel logic for logical clocks, vector clock synchronization, and state merging significantly increases the surface area for split-brain data synchronization bugs. Inconsistent resolution logic between these two modules will inevitably lead to a state where a text block is considered resolved and active, but its parent graph node is considered deleted.

These implementations must be consolidated into a single, unified foundational module (e.g., graph-engine/src/crdt\_core/). Both the textual block kernel and the structural knowledge core must consume the exact same mathematical primitives for time tracking and conflict resolution.

## **Obsolete Intent Schemas**

The directory Epistemos/Intents/Schemas/ contains several files, notably SystemSearchIntent.swift and WordProcessorIntents.swift, that appear structurally disconnected from the active application logic. A comparison against Epistemos/Intents/Custom/NavigationIntents.swift and Epistemos/Intents/EpistemosShortcutsProvider.swift reveals that modern Apple App Intents are primarily routed through the custom entity definitions (NoteEntity.swift, FolderEntity.swift). The legacy schema definitions are likely artifacts of an older SiriKit implementation that was abandoned during the transition to the modern App Intents framework. These legacy schema definitions should be removed to reduce compilation overhead.

## **Section 4: Performance / Consistency / Safety Opportunities**

This section details highly nuanced bugs, race conditions, and architectural inconsistencies discovered via deep adversarial simulation passes across the codebase. These issues operate below the surface of simple compilation errors and directly impact operational reliability.

## **The Silent TK1 Downgrade Vulnerability**

While the transition to TextKit 2 is functionally active, NSTextView remains highly volatile regarding backwards compatibility. The framework is designed to seamlessly—and silently—downgrade to the legacy TextKit 1 rendering engine if it encounters API usage or content types that it cannot resolve via NSTextLayoutManager.4

An audit of Epistemos/Views/Notes/ProseEditorView.swift, Epistemos/Views/Notes/NoteImageProcessor.swift, and various text extension helpers reveals latent risks. If any code path attempts to directly access the .layoutManager property of the text view, or inserts an NSTextAttachment utilizing an older NSFileWrapper implementation rather than providing an explicit NSTextAttachmentViewProvider, the OS will instantly fall back to TK1.4 This downgrade permanently breaks the viewport memory optimizations and destroys any custom NSTextElement drawing (such as the AI inline divider), leading to catastrophic UI glitches.

A strict project-wide linting rule must be implemented to actively flag and prevent any access to the .layoutManager property. Furthermore, NoteImageProcessor.swift must be audited to guarantee that all image attachments are strictly engineered to conform to the TK2 NSTextContentManager lifecycle.

## **Search Index Desynchronization During Import Pipelines**

The interaction between Epistemos/Sync/NoteFileStorage.swift and Epistemos/Sync/SearchIndexService.swift during large-scale operations presents a critical persistence hazard. When a user executes a vault restoration or bulk import via VaultImportFileCopier.swift, the file storage system rapidly writes thousands of Markdown files to disk. Simultaneously, the application attempts to push these items to Core Spotlight for indexing.

If the application is forcefully terminated, encounters an out-of-memory crash, or is suspended by the OS halfway through this operation, a severe desynchronization occurs. The SQLite database and the file system will successfully retain the 10,000 imported files, but the Spotlight index will only recognize the fraction that was processed before the interruption. Because the import operation assumes success upon file write, the system will never attempt to re-index the missed files.

To resolve this, Spotlight indexing must be decoupled from the synchronous write path and handled as an eventual-consistency queue. The VaultManifest.swift must implement an SQLite-backed outbox pattern—effectively a queue table tracking is\_indexed boolean flags for every node. The VaultIndexActor.swift should be restricted to strictly polling and processing this outbox, ensuring that interrupted indexing operations simply resume processing the queue upon the next application launch.

## **Render-Loop Memory Allocation in Metal Graph Visualization**

While the logical boolean checks within MetalGraphView.swift were successfully repaired, the fundamental memory pipeline feeding the Metal render loop remains inefficient. During continuous simulation ticks driven by PhysicsCoordinator.swift, the Swift layer appears to be passing a newly instantiated array of SDGraphNode and SDGraphEdge structs across the boundary to update the visualization state.

Allocating and deallocating thousands of complex objects on every frame (typically 60 or 120 times per second) fundamentally violates zero-copy principles and places an immense burden on the Swift Automatic Reference Counting (ARC) system and the underlying memory allocator. This leads to micro-stutters and increased thermal load during graph interaction.

The rendering architecture must pivot to utilize a pre-allocated memory pool or a continuous ring buffer for the Metal vertex and uniform data. Instead of tearing down and rebuilding the arrays in GraphState.swift, specific indices within the pre-allocated buffer should be updated in place via highly optimized memcpy operations driven directly from the FFI boundary, entirely bypassing ARC overhead during the simulation tick.

## **Rust Stale Adjacency and Compaction Correctness**

The relational spatial graph is managed natively by the Rust graph-engine. When the Swift UI layer executes a query via Epistemos/Graph/FilterEngine.swift, it receives an array of pointers or unique scalar IDs representing the graph state at a specific point in time (![][image1]).

If a background sync thread or the BackgroundGraphActor.swift mutates the graph (e.g., deleting a node or executing an aggressive compaction pass) at time ![][image2], the IDs held in Swift memory instantly become stale. If the user subsequently clicks on a node in the UI, Swift passes those now-invalid IDs back to the Rust graph-engine via ecs/systems.rs to execute a physics pull or a cluster query. If Rust blindly trusts these IDs, it will attempt to access deallocated memory or array out-of-bounds indices, resulting in an unrecoverable panic that instantly crashes the entire application.

The Rust FFI boundary must operate under a zero-trust model regarding indices passed from Swift. The ECS architecture must implement generational indices—a composite index containing both the absolute array offset and a monotonically increasing generation counter. When a node is deleted, the array slot generation increments. If Swift passes a stale ID where the generation counter no longer matches the engine's state, Rust can gracefully return a handled Result::Err rather than executing an unsafe panic.

## **Section 5: Stale Tests / Stale Docs / False Narratives**

A codebase's documentation and testing suites must accurately reflect its physical reality. The persistence of contradictory tests and outdated planning documents creates a false narrative that actively misguides future engineering efforts, leading to incorrect architectural assumptions and wasted debugging cycles.

## **The TextKit 2 Parity Myth in Test Suites**

The test files EpistemosTests/TextKit2ParityTests.swift and EpistemosTests/TK1MigrationValidationTests.swift are actively enforcing a false narrative. These suites were designed to guarantee that the new TK2 engine rendered text identically to the legacy TK1 engine during the transition phase.

However, TK2's noncontiguous layout engine calculates geometry in a fundamentally different manner than TK1's contiguous linear layout.7 Demanding strict mathematical parity between NSTextLayoutFragment boundaries and legacy NSLayoutManager glyph rects is impossible and architecturally incorrect. Because the TK1 baseline has been permanently removed from the production path, these comparative tests are strictly dead code. They generate unnecessary continuous integration (CI) overhead and enforce artificial constraints on the new rendering engine.

Both test suites must be deleted. They should be replaced by a streamlined TextKit2GeometryTests.swift suite that asserts correctness based purely on the internal consistency of NSTextLayoutManager element bounds, completely divorced from legacy layout assumptions.

## **Archival of Pre-Migration Planning Documents**

The repository contains numerous Markdown documents detailing the theoretical implementation phases of features that have long since been completed. Files such as docs/plans/2026-03-08-textkit2-migration-design.md, docs/plans/2026-03-09-phase10-integration-parity.md, and docs/audits/2026-03-10-textkit2-parity-audit-report.md clutter the documentation directory.

Keeping these outdated planning documents in the active repository structure creates severe search-result noise when developers attempt to locate current architectural guidelines. All pre-migration planning documents, obsolete technical decision memos, and completed phase checklists must be systematically moved into a dedicated docs/archive/ folder. Furthermore, docs/PROGRESS.md must be updated to explicitly state that the TK2 migration is definitively closed and out of scope for ongoing work.

## **Xcode Membership Drift in Fuzzing Tests**

Dual-language repositories frequently suffer from test execution drift. Advanced chaos testing and concurrency fuzzing routines written in Rust (such as graph-engine/src/advanced\_chaos\_tests.rs and graph-engine/src/hardened\_race\_tests.rs) execute rapidly via standard cargo test pipelines. However, Swift-side fuzzing equivalents, such as EpistemosTests/HardenedASTFuzzTests.swift, often suffer from severe execution decay.

Because comprehensive AST fuzzing in Swift can drastically inflate the duration of standard xcodebuild test runs, developers frequently un-tick these files in the Xcode test plan schemes to speed up local verification passes. Over time, these un-ticked tests rot, failing to compile against newer API signatures because they are effectively hidden from the compiler during routine checks.

The CI configuration must be audited to verify if HardenedASTFuzzTests.swift and ConcurrencyStressTests.swift are actively executing. If they have been intentionally bypassed to optimize local development speed, they must be rigorously isolated into a dedicated "Nightly Hardening" Xcode test plan that is strictly enforced by the remote CI server, ensuring they compile and run without disrupting daily developer velocity.

## **Stale Abstractions in Graph Embedding Tests**

The testing suite EpistemosTests/BackgroundGraphLoadingTests.swift contains lingering references to mock embedding models and vector similarity logic that actually belong to the deferred model routing stack (e.g., LocalModelInfrastructure.swift). While EmbeddingService.swift bridges the gap, testing the exact cosine similarity outputs or inference pipeline configurations within the general background loading suite violates domain boundaries. These specific assertions should be stripped out and reserved for the eventual testing suites of the local 1B/3B/8B model stack, ensuring the graph loading tests focus purely on structural hydration and asynchronous actor execution.

## **Section 6: Fix-Now vs Defer Matrix**

To execute this pruning pass without destabilizing the application's current green verification state, remediation efforts must be strictly prioritized based on immediate risk versus the required engineering investment. The following matrix categorizes all findings to prevent speculative, high-risk refactoring from dominating the sprint.

| Subsystem / Finding | Category | Status / Priority | Justification and Tactic |
| :---- | :---- | :---- | :---- |
| **Actor Reentrancy in VaultIndexActor** | Concurrency / Safety | **Fix Now (Critical)** | Reentrant actors mutate state unpredictably under asynchronous load, leading to data corruption.2 Implement synchronous boolean locking or FIFO actor-isolated queues. |
| **TK2 Viewport Layout Jank** | UX / Performance | **Fix Now (High)** | The dynamic scrolling "jiggery" destroys the editor experience on large files.6 Implement document chunking or override scroll anchor estimations in ScrollStability.swift. |
| **Spotlight Unbatched Indexing** | Disk I/O / Battery | **Fix Now (High)** | Sequential single-item indexing triggers massive disk writes during sync.11 Must immediately wrap logic in beginIndexBatch and utilize clientState tracking.13 |
| **Stale TK1 Suffixes (\*2.swift)** | Dead Code / Xcode Drift | **Fix Now (Medium)** | Retaining legacy file names post-migration creates significant cognitive load and binary bloat. Rename the files and purge all orphaned \*2.swift instances from .pbxproj. |
| **Stale Parity Tests (TK1Migration...)** | CI / False Narratives | **Fix Now (Low Risk)** | Tests asserting identical behavior between TK1 and TK2 are mathematically flawed and obsolete. Deleting dead code is zero-risk and immediately accelerates the test suite. |
| **CRDT Duplication in Rust Engine** | Architecture / Risk | **Fix Now (Medium)** | Maintaining dual CRDT resolution logic (block\_kernel vs knowledge\_core) guarantees eventual split-brain bugs. Merge into a unified crdt\_core module immediately. |
| **Rust Generational FFI Indices** | Safety / Stability | **Fix Now (Medium)** | Passing stale raw indices from Swift to Rust causes fatal panics. Implement generational tracking to return graceful Result::Err payloads upon stale access. |
| **Graph-Engine FFI Zero-Copy Optimization** | FFI Performance | **Lower Priority** | This is a highly valid performance critique 15, but transitioning to FlatBuffers/MessagePack requires significant Rust ABI refactoring. Defer unless profiling proves it is the primary render bottleneck. |
| **EventBus / ActivityTracker Redundancy** | Architecture | **Lower Priority** | The multiple pub/sub systems are messy but functionally stable. Consolidating event pipelines across the entire app is a massive, high-risk refactor with low immediate UX payoff. Defer. |
| **LLMService / TriageService Hardening** | Feature Planning | **Deferred** | Explicitly excluded per the audit parameters. Do not touch. Re-audit after the 1B/3B/8B model stack migration is fully completed. |
| **VaultSync Destructive Stop** | Safety | **Already Fixed** | The atomic file system fallback logic has been verified as correct. No further action or refactoring required. |

## **Section 7: Exact Recommended Cleanup Sequence**

To systematically eliminate the identified debt without disrupting the stable main branch, engineering teams must execute the remediation in strict, isolated phases. Proceeding out of order risks compounding compilation errors across the language boundary.

## **Phase 1: Excision and Deletion (Low Risk, Immediate Yield)**

1. **Purge Stale Tests:** Immediately delete TextKit2ParityTests.swift and TK1MigrationValidationTests.swift. Execute a clean xcodebuild test to ensure no cascading dependencies exist.  
2. **Archive Stale Documentation:** Move all 2026-03-\* planning documents, migration designs, and completed audit checklists to docs/archive/. Update docs/PROGRESS.md to formally close the TextKit 2 migration epoch.  
3. **Resolve Suffix Drift:** Delete the dead BlockRefAutocomplete.swift and TransclusionOverlayManager.swift files. Rename their \*2.swift counterparts to assume the primary namespace. Critically, update the Xcode .pbxproj file references to ensure successful compilation.

## **Phase 2: Actor Safety and Persistence Hardening (High Risk, Critical Value)**

4. **Audit Actor Suspensions:** Systematically search VaultIndexActor.swift and VaultSyncService.swift for all instances of the await keyword. Introduce a private var isProcessing \= false synchronous lock mechanism around multi-step transactions to categorically prevent reentrant interleaving.  
5. **Implement Spotlight Batching:** Refactor SearchIndexService.swift to ensure all CSSearchableItem updates are array-batched. Implement beginIndexBatch and endIndexBatch. Introduce a SearchIndexData struct for clientState tracking to halt redundant indexing passes on launch.  
6. **Deploy SQLite Outbox:** Ensure NoteFileStorage.swift strictly appends to an SQLite outbox table for indexing requests rather than calling SpotlightIndexer directly in a loop, ensuring eventual consistency during crash recoveries.

## **Phase 3: TextKit 2 Layout and Render Stability (Medium Risk, High UX Value)**

7. **Lint TK1 Fallbacks:** Execute a global repository regex search for .layoutManager. Replace or wrap any legacy property calls to prevent silent rendering downgrades. Audit NoteImageProcessor.swift to ensure strict TK2 attachment lifecycle compliance.  
8. **Implement Scroll Anchoring:** Audit ScrollStability.swift and ProseTextView2.swift. Implement geometry caching for NSTextLayoutFragment elements that have scrolled out of the viewport to suppress usageBoundsForTextContainer from calculating dynamic shifts, stabilizing the total document height estimation.

## **Phase 4: FFI and Rust Parity (Medium Risk, Systemic Value)**

9. **CRDT Consolidation:** Merge graph-engine/src/block\_kernel/crdt.rs and graph-engine/src/knowledge\_core/crdt.rs into a singular utility module. Point both the block kernel and knowledge core consumers to this unified logic. Run cargo test across all comprehensive graph suites.  
10. **Deploy Generational Indices:** Refactor graph-engine/src/ecs/systems.rs to validate the specific generation counter of incoming Swift node IDs. Ensure that stale IDs safely return a handled error rather than panicking the Rust bridge instance.  
11. **Optimize Metal Buffer Writes:** Shift the MetalGraphView.swift render loop to update specific buffer indices via pointer arithmetic or memcpy from the FFI boundary, eliminating the continuous ARC overhead of rebuilding the full SDGraphNode arrays on every tick.

*Report concludes. Following the successful execution of this pruning sequence, a distinct, follow-up research pack must be generated to audit the Omega/Agent stack once the local 1B/3B/8B model routing infrastructure has been fully integrated into the mainline branch.*

#### **Works cited**

1. The Complete Guide to Swift Concurrency: From Threading to Actors in Swift 6 | by Neeshu Kumar | Medium, accessed March 26, 2026, [https://medium.com/@thakurneeshu280/the-complete-guide-to-swift-concurrency-from-threading-to-actors-in-swift-6-a9cf006a19ac](https://medium.com/@thakurneeshu280/the-complete-guide-to-swift-concurrency-from-threading-to-actors-in-swift-6-a9cf006a19ac)  
2. Resolving a Race Condition Bug in Swift Concurrency \- Reddit, accessed March 26, 2026, [https://www.reddit.com/r/swift/comments/1dkqw6f/resolving\_a\_race\_condition\_bug\_in\_swift/](https://www.reddit.com/r/swift/comments/1dkqw6f/resolving_a_race_condition_bug_in_swift/)  
3. Blog \- Actor Reentrancy in Swift \- Michael Tsai, accessed March 26, 2026, [https://mjtsai.com/blog/2024/07/29/actor-reentrancy-in-swift/](https://mjtsai.com/blog/2024/07/29/actor-reentrancy-in-swift/)  
4. TextKit2: A Top-Down Approach \- Flyingharley.dev, accessed March 26, 2026, [https://flyingharley.dev/posts/text-kit2-a-top-down-approach](https://flyingharley.dev/posts/text-kit2-a-top-down-approach)  
5. Blog \- TextKit 2: The Promised Land \- Michael Tsai, accessed March 26, 2026, [https://mjtsai.com/blog/2025/08/15/textkit-2-the-promised-land/](https://mjtsai.com/blog/2025/08/15/textkit-2-the-promised-land/)  
6. TextKit 2 \- the promised land \- Marcin Krzyżanowski, accessed March 26, 2026, [https://blog.krzyzanowskim.com/2025/08/14/textkit-2-the-promised-land/](https://blog.krzyzanowskim.com/2025/08/14/textkit-2-the-promised-land/)  
7. TextKit 2 Reference | Skills Marketp... \- LobeHub, accessed March 26, 2026, [https://lobehub.com/skills/comeonoliver-skillshub-axiom-textkit-ref](https://lobehub.com/skills/comeonoliver-skillshub-axiom-textkit-ref)  
8. TextKit 1/2 behaviour : r/swift \- Reddit, accessed March 26, 2026, [https://www.reddit.com/r/swift/comments/1fognf2/textkit\_12\_behaviour/](https://www.reddit.com/r/swift/comments/1fognf2/textkit_12_behaviour/)  
9. TextKit 2: is it reliable? \- Other Software & Development \- Literature & Latte Forums, accessed March 26, 2026, [https://forum.literatureandlatte.com/t/textkit-2-is-it-reliable/144184](https://forum.literatureandlatte.com/t/textkit-2-is-it-reliable/144184)  
10. Adding your app's content to Spotlight indexes | Apple Developer Documentation, accessed March 26, 2026, [https://developer.apple.com/documentation/CoreSpotlight/adding-your-app-s-content-to-spotlight-indexes](https://developer.apple.com/documentation/CoreSpotlight/adding-your-app-s-content-to-spotlight-indexes)  
11. What's New in Core Spotlight for iOS and macOS \- WWDC 2017 \- Nonstrict, accessed March 26, 2026, [https://nonstrict.eu/wwdcindex/wwdc2017/231/](https://nonstrict.eu/wwdcindex/wwdc2017/231/)  
12. Implementing App Search and Spotlight Integration in iOS Apps \- Reintech, accessed March 26, 2026, [https://reintech.io/blog/implementing-app-search-spotlight-integration-ios-apps](https://reintech.io/blog/implementing-app-search-spotlight-integration-ios-apps)  
13. Core Spotlight integration for Spotlight and internal app search \- Nil Coalescing, accessed March 26, 2026, [https://nilcoalescing.com/blog/CoreSpotlightIntegration](https://nilcoalescing.com/blog/CoreSpotlightIntegration)  
14. App Search Programming Guide: Index App Content \- Apple Developer, accessed March 26, 2026, [https://developer.apple.com/library/archive/documentation/General/Conceptual/AppSearch/AppContent.html](https://developer.apple.com/library/archive/documentation/General/Conceptual/AppSearch/AppContent.html)  
15. surrealdb-ffi-codec | Skills Marketp... \- LobeHub, accessed March 26, 2026, [https://lobehub.com/skills/yuzamesan3-surrealdb-ffi-codec](https://lobehub.com/skills/yuzamesan3-surrealdb-ffi-codec)  
16. swift-bridge \- generate FFI bindings between Rust and Swift : r/rust \- Reddit, accessed March 26, 2026, [https://www.reddit.com/r/rust/comments/rqr0aj/swiftbridge\_generate\_ffi\_bindings\_between\_rust/](https://www.reddit.com/r/rust/comments/rqr0aj/swiftbridge_generate_ffi_bindings_between_rust/)  
17. Swift vs. Rust \-- an Overview of Swift from a Rusty Perspective \- DEV Community, accessed March 26, 2026, [https://dev.to/rhymu/swift-vs-rust-an-overview-of-swift-from-a-rusty-perspective-18c7](https://dev.to/rhymu/swift-vs-rust-an-overview-of-swift-from-a-rusty-perspective-18c7)  
18. Guide to zero-copy FFI with Rust and Unity \- Test Double, accessed March 26, 2026, [https://testdouble.com/insights/rust-unity-zero-copy-ffi-guide](https://testdouble.com/insights/rust-unity-zero-copy-ffi-guide)  
19. hugegraph-store/docs/distributed-architecture.md \- Git repositories on apache, accessed March 26, 2026, [https://apache.googlesource.com/incubator-hugegraph/+show/HEAD/hugegraph-store/docs/distributed-architecture.md](https://apache.googlesource.com/incubator-hugegraph/+show/HEAD/hugegraph-store/docs/distributed-architecture.md)

[image1]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAA4AAAAYCAYAAADKx8xXAAAAmElEQVR4XmNgGDlgMxD/JwHDAYgThiwAFUNRBAQayGJCDBAbkQETA0TBBTRxEHgEY2wFYkYkCRAoYIBo9EcTZwPiPhgnH0kCBt4zYDoTBASAWBxdEBlg8x9BwMwA0XQGXYIQKGeAaPRGlyAEPjOQ4UwQIMt/oOAmy3+zGSAaE9DEsYIgIP7GAIm7t1AM8ucvBjKcPAoGBAAAiastbKanIo0AAAAASUVORK5CYII=>

[image2]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAC8AAAAYCAYAAABqWKS5AAABDklEQVR4Xu2UTQqBURSGX+RnQMnEFizA3AIUZcBUWQAT2YWBqYk1kB0YGliDn6LIQFEmnNuldDr6ru+Pcp96Ju89X73f7XQBi+U/mZC3D/wGOx48UYXqQsaLFoQsSBZwuLQc9M2/EoUeVh9zljxwIE52efghY7wpPyUjLOtAD1dZniD7LHMihQDLt3lAHCEPZ8k8Dx1II8DyEm93zAUZhFg+Bj045wcuCbV8D3qwzA8MKAqWyIGQK00xLn+C4aBARbBBjoRcaYpxeT/3XRHa2qin0M99V4RWfgg91GS5F/woP4PuleQHNfIM/bYfHqq9v8Lgbw3wUv5Cbsk1uSI35J5svQ4FiZfyFovF8gPcAbelVOFkC9RSAAAAAElFTkSuQmCC>