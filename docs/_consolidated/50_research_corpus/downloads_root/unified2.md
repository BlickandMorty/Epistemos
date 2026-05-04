# Unified-Substrate Architecture: A Technical Dossier for a Native macOS AI Knowledge Tool
*A deep systems architecture research memo for a 250,000-line Swift 6 / Rust / Metal macOS application targeting macOS 26.*

***
## 1. Executive Thesis
A 250,000-line modular macOS application has accumulated hidden architectural debt that is not visible in any single module: it lives in the gaps between modules. Each surface — note windows, graph view, sidebar, settings, landing panel — has built its own mental model of identity, its own cache, its own event vocabulary. The cost of this is paid not once but on every cross-surface operation: state disagreements, redundant allocations, duplicated caches, view models that diverge from truth, and a growing surface area for races. The goal of reconceptualization is not to delete features. It is to stop paying that tax.

The path forward is a **unified semantic substrate**: a single runtime machine whose canonical truth lives in Rust-owned storage, whose identities are stable generational keys, whose action grammar is a typed event log, and whose many windows and surfaces are stateless projections over shared state. This is architecturally achievable in a Swift 6 + Rust + Metal stack without abandoning AppKit affordances, without a full rewrite, and without sacrificing the native macOS quality that distinguishes the app from Electron competitors.

The claim this dossier defends: *architectural singularity at the substrate level is not an academic aspiration — it is a precondition for building a large, high-quality, performant native AI knowledge tool that does not collapse under its own weight.*

***
## 2. The Unified-Substrate Manifesto
### On the Hidden Tax of Fragmented Modularity
Modularity is the correct answer to the wrong question. The question "how do we keep modules decoupled?" produces modules with local truth, local caches, and local identity systems. When a note exists as an `NoteViewModel` in the sidebar, as a graph node in the hologram view, and as a document in the editor window — with three distinct identity representations and no guaranteed synchronization — you have not achieved modularity. You have achieved three separate apps sharing a process. Every cross-surface action now requires translation work. Every cache must be invalidated independently. Every undo history operates in local scope. The modularity tax compounds with every new surface.[^1]
### On False Singularity
The opposite failure is the monolithic singletons antipattern: a global state object that everything observes, causing full-app redraws on any mutation. This is not unified substrate — it is unified spaghetti. The goal is not to share *all* state; it is to share *canonical* state. Projection layers remain separate. View models remain separate. But they derive from one truth, not from parallel truths.[^2]
### On Windows as Apertures, Not Worlds
In a correctly designed multi-window app, a window is a lens. It frames a view into the shared semantic graph. Opening a second note window does not create a second copy of that note's truth — it opens a second projection over the same canonical backing. Closing a window does not destroy state — it removes a projection. This is how `NSDocument`-based apps were originally designed, but it is more precisely modeled by GPUI's entity model, where entities are owned by the application context and windows are just rendering surfaces over entity-backed views.[^1][^3]
### On Identity
Every object in the system — every note, block, graph node, agent task, tool result — must have one stable identity that is valid across all windows, all views, all serialization boundaries. The correct tool is the generational index: a (`slot`, `generation`) pair that survives deletions, prevents ABA-problem aliasing, and can be cheaply validated. An entity whose slot has been freed and reused will have a new generation; stale references become immediately detectable. This identity system must be defined at the Rust substrate level and projected upward through the FFI into Swift views.[^4][^5]
### On the Action Grammar
Commands, edits, tool calls, agent actions, and UI gestures are all the same thing from the substrate's perspective: a typed, serializable action that mutates state through a defined pathway. There is one action grammar, not one per module. The macOS responder chain already embodies this philosophy: `NSApplication.sendAction` routes a typed selector along the key window's responder chain to the first object that claims it, without the sender needing to know who handles it. A unified substrate extends this to typed Rust enums, typed SwiftUI actions (in GPUI's model: user-defined structs dispatched against the context tree), and an append-only event log that records every action for undo, sync, and agent replay.[^6][^7][^3]
### On Compactness
Compactness is not binary size reduction alone. It is semantic compression: the fewest concepts needed to describe all behaviors. A system with seventeen kinds of "item" types, eleven view model protocols, and six cache implementations is not compact even if the binary is small. Compactness means: one identity system, one ownership model, one action vocabulary, one rendering contract. The binary size savings follow naturally. So does maintainability. So does performance — because systems that are semantically compact have fewer surprise interactions, fewer redundant copies, and fewer GC / ARC pressure points.
### On Ownership Clarity
Swift's ARC and Rust's ownership model are not enemies — they are complementary guarantees for different parts of the system. Rust owns the canonical, shared, long-lived data: the semantic graph, note storage, agent task queue, event log. Swift owns the ephemeral, view-scoped, non-shared projection state: layout caches, animation state, focus rings, transient selection. The FFI boundary between them is not a cost center — it is a **semantic firewall** that enforces the distinction.[^8]

***
## 3. Key Architectural Findings
### Finding 1: UniFFI Is Not Suitable for Hot Paths
UniFFI, Mozilla's current-generation Swift-Rust bridge, achieves ergonomic bindings at a significant performance cost: every call serializes arguments to a byte buffer and deserializes on the other side. BoltFFI benchmarks show 1000x+ faster echo calls and 589x faster counter increments vs. UniFFI. For read-heavy hot paths — node lookup, layout query, scroll position update — this serialization overhead is unacceptable. UniFFI is appropriate only for coarse, infrequent operations (agent task dispatch, large document saves). For fine-grained hot paths, hand-rolled C ABI structs with `#[repr(C)]` on the Rust side and unsafe but controlled `UnsafePointer` on the Swift side are the correct tool.[^8][^9][^10]
### Finding 2: GPUI Is the Most Relevant Architectural Reference
Zed's GPUI is the strongest real-world analog for the architectural goals described here. Its three-register model — (1) Entities for shared application state, (2) Views (entity + Render) for declarative UI, (3) Elements for low-level imperative rendering — maps directly to the substrate architecture this dossier recommends. Its action system (typed structs dispatched through a window/entity context tree) is the correct abstraction for a unified action grammar. Its Metal backend on macOS achieves the 8ms/frame target at 125fps. GPUI is Rust-native, however. For a Swift 6 / Rust hybrid, GPUI is a *conceptual* reference, not a direct dependency — but its architecture informs the design decisions in every section below.[^11][^12][^3]
### Finding 3: The @Observable Macro Is a Significant Upgrade for Swift Projections
Swift's `@Observable` macro (Swift 5.9+, macOS 14+, targeting macOS 26) provides property-level observation tracking instead of object-level. This means a SwiftUI view that reads only `note.title` will not re-render when `note.content` changes. Combined with the Swift 5.10 `Observations` type providing an `AsyncSequence` of batched state changes, the Swift projection layer can be made highly efficient. The catch: observation tracking re-registers on every body evaluation, and heavy body functions will pay this cost on every frame.[^13][^14][^15]
### Finding 4: SwiftUI Text Performance Is a Hard Constraint
SwiftUI's built-in `Text` component has confirmed performance issues with large volumes of text. For note content, a hybrid approach is mandatory: AppKit's `NSTextView` (TextKit 2 path via `NSTextLayoutManager`) for editable content, wrapped in `NSViewRepresentable`, with SwiftUI reserved for structural chrome. Large-list rendering requires custom recycling via rotating fragment IDs rather than vanilla `LazyVStack`.[^16][^17][^18]
### Finding 5: Python's Role Must Be Sharply Constrained
Python startup on macOS is 22–37ms for bare interpreter, 100–400ms with typical imports. macOS fork() is increasingly dangerous with CoreFoundation threads active. PyO3 calling overhead is 20–40ns per call, compounding with GIL acquisition costs. Python must not be in the substrate. Its correct role is an isolated tool executor: a pre-warmed daemon with a Unix socket interface, callable for scripted tool operations, but never in the rendering loop, never in the action path, and replaceable with native Rust/Swift implementations for performance-critical tools.[^19][^20][^21][^22][^23]
### Finding 6: ECS Is Viable for Non-Game Productivity Apps
Bevy ECS (and Hecs, Flecs for lighter options) has demonstrated production viability outside games: circuit board state modeling, embedded Rust applications, and explicitly confirmed in 2025 conference talks as a general systems architecture pattern. The cache-locality and parallelism benefits of flat component arrays are real for note/graph data with many entities (tens of thousands of nodes, edges, blocks). The cost is conceptual overhead for team members unfamiliar with the pattern.[^24][^25][^26]

***
## 4. Best Reference Systems and Why They Matter
### GPUI (Zed Industries)
The strongest reference for the full architecture. Entity-owned state, typed action grammar, GPU-accelerated rendering at 1M px/ms, multiple window support via app context + entity references, foreground/background async executor integrated with GCD. The multi-window limitation noted in Zed issues (independent project management across windows) illustrates the exact challenge this app must solve differently — by designing the shared entity graph to be window-agnostic from day one.[^11][^27][^28]
### TextKit 2 (Apple)
The correct text rendering substrate for editor-class notes content. NSTextLayoutManager provides correct, performant layout for complex text. The trap is TextKit 1 compatibility mode: triggered automatically if any legacy delegate or subclass is used, silently degrading to slower path. All TextKit 2 code must be written with explicit guard against compatibility-mode activation.[^16]
### Bevy ECS
The clearest demonstration of data-oriented design at scale: flat component arrays, parallel systems, generational entity keys. The correct inspiration for the Rust substrate's node/edge storage. Not a dependency — a mental model.[^29][^24]
### NSDocument + NSWindowController
Apple's established multi-window pattern: 1:1 NSWindowController to NSWindow relationship. The document model is the right inspiration for the "window as lens" pattern, but it conflates identity too strongly with file system objects. The substrate must generalize this: any entity (not just documents) can have multiple window projections.[^1]
### Event Sourcing (LiveStore, CQRS pattern)
The event log as ground truth for state, sync, agent replay, and undo. In the substrate: every mutation is an `AppAction` enum value appended to an ordered log. The current observable state is a projection over that log. This gives free undo/redo, free agent replay, free sync foundation, and free debugging.[^30][^31][^32]

***
## 5. Zero-Copy and Ownership Model Research
### Where Zero-Copy Is Realistic
**Rust-to-Rust: rkyv-archived storage.** rkyv achieves true zero-copy deserialization: the in-memory layout of archived data matches the wire format exactly, enabling access via pointer arithmetic without any struct reconstruction. For the substrate's canonical node/edge storage (graph topology, note metadata), rkyv-archived blobs loaded via `mmap` are genuinely zero-copy. The constraint: rkyv's format is internal only, not human-readable, and requires Rust on both ends.[^33][^34]

**FFI boundary: `#[repr(C)]` structs with pointer borrowing.** For read-heavy, hot-path queries (e.g., "give me the title and type of node X"), a flat `#[repr(C)]` struct with raw byte slices pointing into Rust-owned storage, passed to Swift as `UnsafeRawBufferPointer` scoped to the Rust borrow lifetime, achieves near-zero-copy. The guarantee: the Rust side must keep the storage live for the duration of the Swift borrow. In practice, this is achieved by passing a scoped closure that Swift must complete synchronously before returning control to Rust.[^8][^35]

**Metal: GPU buffer reuse.** Metal's triple-buffering model for dynamic data achieves zero-copy in the GPU pipeline sense: CPU writes to the current back buffer, GPU reads from the previous, no synchronization stalls. Ring buffers allocated once at app startup and reused per frame eliminate per-frame allocation entirely.[^36]
### Where Zero-Copy Is Fake Ideology
**Any Swift String crossing the boundary is a copy.** Swift `String` is value-typed, UTF-8-stored, with a null terminator trick for C interop that copies the bytes into a new allocation. There is no zero-copy Swift String bridging to Rust `&str`. Strategic approach: keep human-visible strings in Rust as `Cow<str>` or interned symbol IDs; pass only IDs across the FFI, resolve to display strings in the Swift layer on demand.[^8]

**SwiftUI view bodies are re-evaluated, not diffed incrementally.** SwiftUI's `body` recomputation is cheap (struct construction), but every property access registers an observer (via `@Observable`) and every struct copy allocates for non-trivial types. "Zero-copy SwiftUI" is a fiction. The correct approach is to pass minimal view data (IDs, scalars, small value types) to SwiftUI views and let them fetch display strings lazily.[^2]

**UniFFI is copy-through by design.** Every UniFFI call serializes arguments. There is no zero-copy path in UniFFI. This is a documented design choice trading performance for ergonomics. For a hot path like scroll events, frame callbacks, or node hover detection, UniFFI must be replaced.[^10]

**Python boundary.** Every Python↔Rust data exchange through PyO3 involves Python object creation, GIL acquisition, and potential memory pinning until the GIL is next dropped. This is structurally incompatible with zero-copy semantics. The correct architecture is to never put Python on any hot path.[^37][^22]
### Where Strategic Copying Is Correct
**Snapshot copies for rendering frames.** The render thread should not hold live references into the mutable substrate. The correct pattern is a per-frame snapshot copy of the minimal state needed to render: a list of (node_id, position, color, label_id) tuples, not references into the live graph. This intentional copy creates a clear rendering/mutation boundary.

**Event log entries are immutable value copies.** Every action appended to the event log should be a complete, self-contained value. No references into mutable storage. This enables log replay, serialization, sync, and debugging without concern for reference lifetime.

**Text content across TextKit boundary.** `NSTextStorage` maintains its own copy of text content. Attempting to share backing storage between Rust and TextKit 2 would require implementing a custom `NSTextStorage` subclass that delegates to a Rust buffer — possible but fragile. The strategic copy here is correct: text edits flow as `TextAction` events through the action log, Rust applies them to its canonical storage, and TextKit has its own synchronized copy for display. The latency budget for this copy (a few hundred microseconds for typical note content) is well within the 8ms frame budget.
### The Memory Law
| Domain | Owner | Lifetime | Crossing Boundary |
|---|---|---|---|
| Canonical nodes/edges/blocks | Rust (slotmap/arena) | App session | ID-only; #[repr(C)] for read queries |
| Event log entries | Rust (append-only vec) | Persistent / replay | Serialized to SQLite for sync |
| Text content (display copy) | TextKit NSTextStorage | Per-editor-window | TextAction events; NSString copies accepted |
| View layout cache | Swift | Per-frame / invalidate | Never crosses to Rust |
| GPU buffers | Metal (MTLBuffer) | Session (triple-buffered) | Never crosses to Swift |
| Agent context | Rust + SQLite | Task session | ID refs into canonical graph |
| Python process memory | Separate process | Tool call lifetime | IPC payload; never shared memory |

***
## 6. Binary Size and Compactness Research
### Swift Binary Size Contributors
Swift's generics, protocol witnesses, and metadata tables are the dominant binary size factors. Every concrete generic instantiation produces a full copy of the generic's machine code unless the whole-module optimizer (WMO) can devirtualize and specialize across module boundaries. With WMO enabled for release builds, the Swift compiler can eliminate dead generic instantiations and cross-file specializations that incremental mode cannot see. The WWDC 2022 Swift runtime improvements moved protocol conformance checks to precomputed dyld closure data — up to half of launch time saved on apps with many protocol types. Message send stubs provide an additional 2% code size reduction.[^38][^39][^40]

Practical levers: (1) Enable WMO for all release builds. (2) Reduce protocol sprawl — fewer protocols means fewer witness tables. (3) Use `@inlinable` sparingly — it embeds function bodies into caller modules, expanding binary size. (4) Audit framework embed count — each embedded Swift framework carries its own Swift runtime copy if the app targets older OS versions; macOS 26 target removes this entirely (Swift is system-provided).
### Rust Binary Size Contributors
The Rust compiler produces large binaries by default due to monomorphization of generics and full debug info. The aggressive optimization path is well-documented: `opt-level = "z"` (size-optimize), `lto = true` (cross-crate dead code elimination), `codegen-units = 1` (single LLVM unit for maximum optimization scope), `panic = "abort"` (eliminates unwind tables), `strip = true` (symbol stripping). A minimal hello-world Rust binary optimized this way reaches ~150–200KB. A production Rust library with serialization, graph storage, and async runtime will realistically occupy 2–8MB of the final app bundle.

LTO across the Swift/Rust boundary via a thin C static library is possible but produces a bifurcated LTO domain: Swift modules optimize among themselves, Rust crates optimize among themselves, but cross-language LTO requires explicit bitcode embedding and is not supported out of the box. The practical approach: treat the Rust library as an opaque static archive (.a), expose a minimal C ABI surface, and let LLVM/LTO prune both sides independently.
### UniFFI vs. Custom C ABI
UniFFI adds generated Swift bindings, a scaffolding runtime, and serialization code on both sides. For a production app where binary size and call overhead matter, custom C ABI with cbindgen-generated headers is the correct long-term choice. The migration path: UniFFI for rapid initial development and prototyping, incremental replacement of hot-path calls with hand-rolled C ABI wrappers as profiling identifies bottlenecks.[^9]
### Realistic Size Lower Bounds
For a pro-grade macOS knowledge app with graph rendering, rich text, Metal-accelerated views, and an embedded agent runtime:

| Component | Realistic Min | Note |
|---|---|---|
| Swift/AppKit/SwiftUI code (WMO, stripped) | 8–15 MB | 250k LOC → substantial after WMO |
| Rust static library (z-opt, LTO, strip) | 3–8 MB | Depends on dependencies |
| Metal shaders (.metallib) | 0.5–2 MB | One metallib per pipeline family |
| Assets (icons, fonts) | 1–5 MB | Symbol images amortize font cost |
| Python (if bundled) | 60–120 MB | CPython + stdlib alone; unavoidable if bundled |
| Python (subprocess, minimal) | 5–20 MB | Only required packages |

**"5 MB total" is fantasy for this feature set.** A realistic minimum, excluding Python, is 15–30 MB for a stripped, optimized build. With Python bundled, 80–150 MB is the honest floor. The correct way to achieve compactness is: (1) Do not bundle Python; use a subprocess daemon with minimal pip packages. (2) Use a single Rust binary for all Rust logic (avoid multiple dylibs). (3) Consolidate all Metal shaders into one metallib compiled at build time.

***
## 7. Multi-Window Singularity Architecture
### The Window as Lens Pattern
The foundational insight is that `NSWindowController` lifecycle (1:1 with NSWindow) should not be conflated with *data ownership*. The correct design: each window controller holds an `EntityID` that identifies *what context it is displaying*, not a copy of the data itself. Opening a second window for note X creates a new `NoteWindowController` with the same `noteID` pointing into the shared Rust substrate. Mutations from either window flow through the single action grammar to the single canonical store and propagate via `@Observable` to all live window controllers that reference the affected entity.[^1]
### Session State vs. Canonical State
Not all window state should be in the canonical substrate. Window-specific state — scroll position, selection, zoom level, sidebar collapse state, local search query — is **session state**: it belongs to the window projection, not to the entity. Mixing these into the canonical store creates noise in the event log, false invalidations in other windows, and difficulty in sync. The architecture must explicitly classify every piece of state as **canonical** (lives in Rust, propagates to all windows) or **session** (lives in the window controller, does not propagate).
### Focus and Command Routing Across Windows
macOS handles this correctly via the responder chain. `NSApplication.sendAction` routes through: first responder in key window → key window's NSWindow → key window's delegate → main window's chain → NSApp → NSApp delegate. The correct abstraction for a unified action grammar: define all commands as typed `AppAction` enum cases (in Swift) or typed structs (in GPUI style). Key window focuses determine which `AppAction` variants are available. Menu items enable/disable via `validateUserInterfaceItem` by querying the current first responder's capabilities. No global "state machine of what window is active" is needed — the responder chain is that state machine, and it is already correct.[^6][^41][^7]
### Graph / Notes / Chat / Settings as Expressions
All surfaces — note windows, hologram graph, chat sidebar, settings panel — are different **projections** over the same substrate. The graph view renders the topology of entity relationships. The note window renders the content of one entity's text and metadata. The chat sidebar renders the current agent conversation thread (which is itself a sequence of entities in the canonical graph). Settings renders a typed configuration entity. None of these surfaces "own" their data — they read from and write to the canonical store through the action grammar.
### How Pro Apps Do (and Fail at) This
Craft supports multi-window and multi-tab and achieves a mostly coherent shared-document model, but relies on Electron's renderer-process message passing for sync — functionally correct but architecturally wasteful. Bear's native Swift architecture keeps all notes in a SQLite store (one truth), with window projections reading directly from the store. Obsidian migrated to SQLite ("Bases" in 2025) after years of markdown-file fragmentation — illustrating that flat-file local truth eventually loses to database truth as feature scope grows. Zed's multi-window issues stem from project isolation in the entity graph, not from the entity model itself — a different problem.[^42][^27][^43][^44]

***
## 8. Rendering and UI Substrate Architecture
### Recommended Rendering Architecture
The correct architecture for this app is a **tiered rendering stack**:

**Tier 1 — Specialized Metal surfaces.** The hologram/graph view is a Metal-rendered surface: nodes and edges drawn with custom vertex/fragment shaders, GPU-accelerated force-directed layout, particle effects, and spatial audio if applicable. This surface uses a direct `CAMetalLayer` hosted in an `NSView` layer, driven by `CVDisplayLink` at the display's native refresh rate. The render loop reads from a per-frame snapshot of the graph state (a CPU-side copy made once per frame, not a live reference).[^45][^46]

**Tier 2 — AppKit for editor surfaces.** Note windows use `NSTextView` (TextKit 2 path via `NSTextLayoutManager`) for rich text editing, wrapped in appropriate AppKit containers. TextKit 2 provides correct paragraph rendering, attachment handling, and accessibility support that no custom renderer can match. Attempt to replace TextKit with a custom Metal text renderer for main editing content will produce years of maintenance burden and accessibility failures.[^16]

**Tier 3 — SwiftUI for structural chrome.** Toolbars, sidebars, inspector panels, navigation structures, settings, and overlay UI are SwiftUI. WWDC 2025 `NSGlassEffectView` and Scene Bridging APIs make the macOS 26 design language (Liquid Glass) natively available. SwiftUI's `@Observable` macro ensures fine-grained view invalidation. Use `id(_:)` modifiers with stable entity IDs to give SwiftUI unambiguous view identity and prevent spurious list redraws.[^47][^2][^14][^48]
### Invalidation Rules
**One dirty-bit per entity, not per property.** The rendering system should not attempt fine-grained property-level dirty tracking across the FFI. Instead: any mutation to an entity marks that entity's render-version as dirty. The layout engine checks render-versions per entity on each frame. Only entities whose render-version changed since last frame are re-laid out. This is cheap (integer comparison per entity), correct, and avoids the overhead of property-level cross-language observation.

**Diff-driven redraw for lists.** Note lists, search results, and sidebar items use a typed `Diff<T>` stream: `inserted`, `removed`, `updated(from:, to:)` operations computed by the Rust substrate on each state change. The Swift list view consumes this diff stream via `AsyncSequence` and applies `insertItems`, `deleteItems`, and `reloadItems` batch updates — the same pattern used by `UICollectionViewDiffableDataSource`, adapted to AppKit via `NSTableViewDiffableDataSource`.
### Accessibility
Custom Metal rendering surfaces require manual `NSAccessibility` protocol implementation. This is non-trivial: every interactive node in the hologram view that a VoiceOver user might navigate must expose `NSAccessibilityElement` children with correct roles, labels, and actions. The mitigation: design the Metal surface's accessibility overlay as a parallel data structure driven by the same entity graph — a read-only projection of the graph into `NSAccessibilityElement` trees, updated on the same dirty-entity cadence as rendering.
### The IMGUI/Retained Hybrid
GPUI's model is the correct template: retained entities (stable state, not rebuilt each frame) + immediate render pass (Render trait called each frame, building a transient element tree). This avoids the pathological cases of pure retained mode (expensive subtree mutations) and pure immediate mode (no identity, no animation, no accessibility). For this app: the Rust substrate + Swift `@Observable` models are the retained layer; SwiftUI bodies are the immediate render pass over those models.[^49][^3]

***
## 9. Python Runtime Strategy
### The Five Options Compared
| Strategy | Startup Cost | Memory Cost | Call Overhead | Reliability | Recommended For |
|---|---|---|---|---|---|
| Embedded CPython (PyO3) | ~37ms (no site), ~200ms+ with imports[^20][^21] | ~30–80 MB interpreter + heap[^50] | 20–40ns + GIL[^23] | GIL contention; macOS fork issues[^19] | Never in hot paths |
| Isolated subprocess daemon | One-time ~200ms warm-up | Separate process, ~50–100 MB | IPC round-trip ~0.1–1ms | Full isolation, crash-safe | Tool execution |
| On-demand subprocess | Per-invocation ~200ms cold start[^20] | Minimal when idle | Per-call cold start | Simple but slow | Rare batch tasks |
| Replace with Rust/Swift | 0 | 0 | 0 | Best | Performance-critical tools |
| No Python | 0 | 0 | 0 | Best | Default posture |
### Recommended Architecture: The Python Tool Daemon
Python's correct role is as a **pre-warmed, isolated tool execution daemon**. On app launch (background thread, deferred), spawn a Python subprocess with `spawn` (not `fork`) via `Process`. Establish a Unix domain socket for IPC. The daemon loads the tool runtime once and stays warm. Tool invocations become IPC round-trips (~0.1ms for small payloads), not subprocess launches (~200ms). The daemon's memory lives in a separate process; a crash does not affect the main app. The IPC protocol is a simple length-prefixed JSON or msgpack framing over the Unix socket.[^19]

**Packaging.** Bundle only the packages needed for actual tools (e.g., `numpy` for numerical operations, specific AI SDKs). Use `uv` or `pip install --target` to a vendored directory inside the app bundle, avoiding system Python dependency. Total Python payload: 20–50 MB for a lean tool set (vs. 80–120 MB for full CPython + stdlib). Consider using the system Python available at `/usr/bin/python3` on macOS 26 to reduce bundle size, with a fallback to bundled Python for required package versions.

**The non-negotiable rule:** Python must never appear in the rendering loop, the action-routing path, the event log, or the UI invalidation path. It exists only at the tool execution boundary, invoked asynchronously by the agent harness.
### When to Replace Python with Native
Profile-identified hot-path tools (e.g., token counting, markdown parsing, text chunking, regex operations, JSON processing) should be migrated to Rust. The Rust ecosystem has mature, fast alternatives: `pulldown-cmark` for Markdown, `serde_json` for JSON, `tiktoken-rs` for tokenization, `regex` for regex. For numerical work, `ndarray` covers most NumPy use cases. The Python tool daemon should shrink over time as native implementations replace Python tools.

***
## 10. Agentic Harness Substrate Strategy
### The Core Architectural Error to Avoid
The most common agentic harness antipattern is **bolted-on wrappers**: LLM API calls sprinkled across view controllers, tool execution embedded in UI event handlers, context management as a collection of ad-hoc strings. This produces an agent that works in demos and fails in production — no observability, no retry logic, no isolation, no replay, no audit trail. The harness must be designed as a **first-class substrate component**, not as UI scaffolding.
### The Harness as Event-Sourced Runtime
The correct architecture treats every agent operation as a substrate event:

```
AgentAction = 
  | PlanStep(task_id, step_desc, tool_name, tool_args)
  | ToolCall(task_id, step_id, tool_name, serialized_args)
  | ToolResult(task_id, step_id, result_payload, latency_ms)
  | ModelGeneration(task_id, step_id, prompt_tokens, completion_tokens, model_id)
  | TaskCompleted(task_id, final_output)
  | TaskFailed(task_id, error, step_id)
```

These events are appended to the same ordered event log as user actions. This gives: free audit trail, free replay for debugging, free task history, and free UI reflection (any window can observe `AgentAction` events and render task progress without coupling to the agent execution logic).[^51][^30]
### Tool Execution Architecture
Each tool is a typed Rust struct implementing a `Tool` trait:
```rust
trait Tool: Send + Sync {
    fn name(&self) -> &'static str;
    fn call(&self, args: serde_json::Value, ctx: &SubstrateContext) -> ToolResult;
}
```

Native tools (graph query, note search, text chunking) call directly into the Rust substrate. Python tools dispatch to the daemon via IPC. External API tools make async HTTP calls via a rate-limited client with retry logic. The tool registry is a `HashMap<ToolName, Arc<dyn Tool>>` in the substrate, never in UI code. Tool calls are always async, always logged, always isolated from the rendering loop.
### Context Management: Graph-Aware Memory
The agent's context is not a flat chat history. It is a **graph-contextualized memory**: entities referenced in the current task are indexed, their relationships are traversable, and retrieval is entity-centric rather than semantic-similarity-only. The Zep/Graphiti temporal knowledge graph model — episodic events + semantic entity summaries + temporal indexing — is the correct architecture for an agent operating over a user's knowledge graph. The substrate already owns the knowledge graph; the agent memory layer is a projection over it, not a separate store.[^52][^53]

Concretely: when the agent references note X, the substrate indexes note X's entity ID in the current task context, retrieves its N-hop neighborhood (directly linked notes, parent/child graph nodes, recent modification events), and packs this structured context into the LLM prompt. This is structurally richer and more efficient than vector-only RAG.[^30]
### UI Reflection of Agent State
Agent task state should be observable from any window. The canonical architecture: a `TaskQueue` entity in the Rust substrate, observed via `@Observable` in Swift, rendered in a SwiftUI task panel. Each `AgentTask` entity has: `status` (planning / running / completed / failed), `current_step` (string), `tool_history` (Vec of ToolCallEvent IDs), `elapsed_ms`, `error`. The UI does not call the agent; it observes it. Actions flow from the UI into the action log; the agent runtime picks them up from there.
### Isolation Boundaries
Agent execution must not block the UI thread. The foreground executor (main thread / main actor in Swift 6) handles UI mutations. Agent planning and tool execution run on `Task { @MainActor in /* update task entity */ }` with the actual work dispatched to a background actor or Rust background thread. Model generation calls use structured concurrency with cancellation support; a `CancellationToken` (or Swift's `Task.cancel()`) propagates to in-flight HTTP requests and tool calls.[^54]
### Comparison with Reference Harnesses
| System | Architecture | Relevance |
|---|---|---|
| Zed AI (GPUI-native) | Entity-owned AgentSession, Metal-rendered diff stream for inline completions | Closest analogue; same Rust-owned entity model |
| Claude Code | Hybrid context: files loaded eagerly, filesystem tools for JIT retrieval[^55] | Good model for "local-first context engineering" |
| Inngest Utah | Event-driven, durable steps, each tool call = retryable function[^51] | Good model for retry/durability semantics |
| LangGraph | Checkpointed graph execution, step-level replay[^30] | Overkill for single-user native app; concepts valid |

***
## 11. Recommended Architecture for This Stack
### The Architecture: Rust-Owned Semantic Graph + Swift Actor-Isolated Projection + Metal Specialized Surfaces
**The Substrate (Rust, ~40% of logic)**
- Canonical node/edge/block store using `slotmap` generational keys[^4][^5]
- Append-only event log (`Vec<AppAction>` + SQLite persistence)
- Agent task queue and tool registry
- Graph query engine (adjacency traversal, N-hop neighborhood)
- Text diff engine (Myers diff for note content)
- CRDT layer for sync (operation-based)[^56]
- rkyv-archived storage for large immutable payloads (image metadata, embeddings)[^33]
- Exposed via: (a) UniFFI for coarse operations during development; (b) custom `#[repr(C)]` C ABI for hot paths[^8]

**The Projection Layer (Swift 6, @MainActor default, ~45% of logic)**[^54]
- `@Observable` view models derived from Rust substrate entity IDs
- Action dispatch: typed `AppAction` enum → Rust FFI → event log
- Multi-window management: `NSWindowController` subclasses holding entity IDs
- Responder chain integration for menu validation and keyboard command routing[^6]
- Session state (scroll, selection, local search) isolated in window controllers, not in substrate
- SwiftUI for: chrome, toolbars, sidebars, settings, agent task panel
- AppKit / NSTextView for: rich text editor content (TextKit 2 path)

**The Rendering Surfaces (~15% of logic)**
- Hologram/graph view: `CAMetalLayer`-hosted `NSView`, CVDisplayLink-driven, snapshot-per-frame copy of graph positions from Rust substrate[^45][^46]
- Metal shaders: single `.metallib` compiled at build time for all graph rendering
- Custom `NSAccessibility` overlay for Metal surfaces
- SwiftUI Metal shader integration (new macOS 26 API) for glass/visual effects on standard views[^17]
### The Five Laws of This Architecture
1. **Identity is generational and universal.** Every canonical object has a `SlotKey` from the Rust slotmap. No other identity system.
2. **Actions are typed and logged.** Every mutation of canonical state flows through an `AppAction` variant, appended to the event log before any state changes.
3. **Windows own sessions, not data.** Window controllers hold entity IDs and session state. Canonical state lives only in the Rust substrate.
4. **Python is at the periphery.** Python executes only in the isolated daemon. It never touches the action log, the event loop, or the rendering path.
5. **The hot path is C ABI.** No UniFFI on paths called > 1,000 times/second. Custom `#[repr(C)]` structs or direct pointer sharing for read-heavy queries.

***
## 12. Migration Roadmap
### 30-Day Audit Plan
**Week 1: Mapping**
- Instrument every module with allocation profiling (Instruments, Memory Graph, allocations template). Record: peak allocation per module, average cross-module call frequency, duplicate data structures (note X is in how many caches?).
- Map all identity types: every struct, enum, or ID type that "represents" a note, node, block, or task entity. Count how many are in use.
- Map all view models: how many `ObservableObject` / `ViewModel` types exist? Which properties are read-only projections vs. source-of-truth?

**Week 2: Data Flow**
- Trace five cross-surface operations (e.g., rename a note from search result → propagate to graph → propagate to sidebar → propagate to open note window). Document every copy, translation, or notification triggered.
- Identify the top three copy hotspots by allocation volume. These are migration priority 1.
- Audit all UniFFI call sites. Categorize: high-frequency (>100/sec), medium, low. High-frequency calls are C ABI migration candidates.

**Week 3: Boundaries**
- Identify which logic is purely UI (should stay Swift) vs. purely data (should migrate to Rust) vs. currently mixed.
- Assess TextKit usage: are any text-handling code paths going through SwiftUI `Text` for large content? If so, flag for NSTextView migration.
- Assess Python usage: what operations currently use Python? Are any in the rendering or action path?

**Week 4: Risk Map + Baselines**
- Record baseline metrics: app binary size, launch time (Instruments), memory at idle, frame time during graph interaction, frame time during note scroll. These are migration success KPIs.
- Write a formal risk map (see Section 13).
- Identify "no-regret" changes that can begin immediately without architectural commitment.
### 60–90 Day Architectural Migration Plan
**Phase 1 (Days 30–45): Identity Unification**
- Define `EntityID` as a `SlotKey` typedef at the Rust level and expose it to Swift via C ABI.
- Migrate the primary note/node identity to use `EntityID`. All existing identity types become thin wrappers or deprecated aliases.
- This is the highest-leverage early change: once every module uses the same identity type, cross-surface operations become structurally correct.

**Phase 2 (Days 45–60): Action Grammar**
- Define `AppAction` enum in Rust (or a mirrored Swift enum for Swift-originating actions).
- Replace the most-used cross-module notification/callback pairs (e.g., "note renamed" NSNotification, delegate callbacks) with typed `AppAction` variants dispatched to the event log.
- Implement undo/redo as event log replay for actions tagged `undoable: true`.

**Phase 3 (Days 60–75): Window Singularity**
- Migrate the note editor window to read from substrate entity directly (via `@Observable` view model over entity ID).
- Validate that two note windows open on the same note show identical state with <1 frame propagation latency.
- Migrate sidebar to read from the same entity source.

**Phase 4 (Days 75–90): Hot Path C ABI**
- Profile the post-Phase 1-3 build with Instruments.
- Identify the top three UniFFI hot paths. Implement `#[repr(C)]` equivalents with hand-rolled Swift wrappers.
- Benchmark: if call latency drops by >10x, proceed with wider C ABI migration.
### No-Regret Changes (Begin Immediately)
1. Enable WMO for all modules in release configuration. Zero-risk, measurable binary size reduction.[^39]
2. Migrate all `ObservableObject` → `@Observable` macro where macOS 14+ is the floor (confirmed for macOS 26 target).[^14]
3. Add `id(_:)` modifiers with stable entity IDs to all list/grid views.[^2]
4. Move Python invocations to a `Task { }` wrapper with `await` if any are currently on the main thread.
5. Enable `codegen-units = 1` and `lto = "thin"` for the Rust release profile. Thin LTO reduces binary size with manageable build time cost.

***
## 13. Risk Map and Anti-Patterns
### Risk Matrix
| Risk | Severity | Likelihood | Mitigation |
|---|---|---|---|
| TextKit 1 compatibility mode silently activated | High | Medium | Audit all `NSTextStorage` subclasses; add assertion for `NSTextLayoutManager` presence |
| UniFFI call on rendering hot path | High | High (likely existing) | Allocations Instrument profiling before migration; gate on profiler evidence |
| Multiple identity systems surviving unification | High | Medium | Weekly identity audit during Phase 1; compile-time type aliases for legacy IDs |
| Python daemon crash blocking tool execution | Medium | Low | IPC retry with exponential backoff; daemon health check every 30s; graceful degradation |
| SwiftUI view with unstable ID recreating on every rerender | Medium | High (common mistake) | Lint for views with `id(UUID())` or computed IDs inside `ForEach` |
| rkyv format migration across app updates | Medium | Low | Version-tag all rkyv archives; fallback to full re-serialization on version mismatch |
| Metal surface accessibility gaps | Medium | High | Accessibility audit as part of any Metal surface shipping; VoiceOver manual test protocol |
| Event log growing unboundedly | Low | Medium | Log compaction: snapshot canonical state every N events; truncate replayed prefix |
| Agent task blocking main actor | High | Medium | All agent work on background actor; main actor only for entity updates |
### Anti-Patterns to Explicitly Avoid
**The God Observable.** A single `@Observable` class holding all app state, observed everywhere. This produces object-level invalidation (all observers fire on any property change) and is structurally identical to the fragmentation problem it claims to solve.

**The Notification Newspaper.** Replacing typed `AppAction` dispatch with `NotificationCenter` broadcasts for "decoupling." NotificationCenter provides string-typed, stringly-dispatched, unstructured events. Every subscriber must re-check and re-cast. Use typed action enums.

**The Python Hot Path.** Any code path where a Python tool call must complete before a UI update can be displayed. Python must be fire-and-forget with UI reflection via `AgentAction` events.

**The Shared NSTextStorage.** Attempting to share a single `NSTextStorage` across multiple `NSTextView` instances (e.g., for simultaneous note viewing in two windows). TextKit requires separate storage per view hierarchy. The correct pattern is two storage instances, both synchronized from the canonical Rust text buffer via `TextAction` events.

**The Full-Graph SwiftUI View.** Rendering thousands of graph nodes as SwiftUI views. SwiftUI's view hierarchy was not designed for this scale. Metal is the only correct substrate for graph rendering at thousands of nodes. SwiftUI's role in graph context is overlay UI (labels, action menus, selection highlights) positioned over the Metal layer.

**The Monorepo Rust Crate.** Putting all Rust logic in one crate to avoid FFI overhead between crates. This produces a 200KLOC Rust crate with 60-second incremental build times. Correct structure: `substrate-core` (entities, event log), `substrate-graph` (graph algorithms), `substrate-agent` (agent runtime), `substrate-text` (text operations), each as a separate crate with explicit interfaces. The FFI surface is only the outermost layer.

***
## 14. Concrete Audit Checklist
### Identity Audit
- [ ] Count distinct "note identity" types (IDs, UUIDs, file paths, hash-based keys). Target: reduce to 1.
- [ ] Count distinct "graph node identity" types. Target: reduce to 1.
- [ ] Identify any identity types that are Optionals or can be nil. Optional identity = undefined lifetime = bug surface.
- [ ] Confirm all identity types survive serialization round-trips identically.
### Memory Audit
- [ ] Run Instruments Allocations on: launch, note open, graph navigation, agent task, note search.
- [ ] Record: peak RSS, active allocation count, top 10 allocation sites by bytes.
- [ ] Identify any `String` allocations crossing the FFI boundary more than 1,000 times/second.
- [ ] Identify any `Array` or `Dictionary` allocations with >100 elements created per frame.
- [ ] Confirm no Metal textures re-allocated per frame (should be triple-buffered at startup).[^36]
### Cross-Surface Coherence Audit
- [ ] Open same note in two windows. Make a change in one. Measure latency until visible in second (target: <16ms).
- [ ] Rename a note. Count all code paths that must be updated (event handlers, caches, view models). Target: 1 action → 1 log entry → N observers, 0 manual cache invalidations.
- [ ] Delete a node in graph view. Confirm note list, sidebar, and any open note windows reflect deletion without crash or stale reference.
### Python Audit
- [ ] List all Python invocations in codebase. Categorize: sync (blocking), async, in-process, subprocess.
- [ ] Confirm no Python invocations on the main thread.
- [ ] Measure Python daemon startup time. Record: cold start, warm invocation, crash recovery time.
### Rendering Audit
- [ ] Measure frame time during: empty state, 100-note list scroll, graph with 1,000 nodes, graph with 10,000 nodes.
- [ ] Confirm Metal surface renders 0 frames when window is minimized or occluded (not just hidden).[^57]
- [ ] Confirm CVDisplayLink callback is dispatched on non-main thread and only submits UI updates via `DispatchQueue.main.async`.
### FFI Audit
- [ ] List all UniFFI call sites. Measure call latency with Instruments. Flag any >10µs average latency on paths called in render/scroll loops.
- [ ] Confirm all `#[repr(C)]` structs have explicit alignment annotations and are validated with `std::mem::size_of` tests.
- [ ] Confirm no Rust `Box<T>` is passed across the FFI boundary without explicit `into_raw()` / `from_raw()` contract documentation.

***
## 15. Final Verdict
### Should the App Keep Modularity?
Yes — at the surface level. The landing window, graph view, note editor, settings, and agent panel are correctly separate surfaces. They have different interaction models, different rendering requirements, and different lifecycles. Architectural modernity does not require destroying this surface modularity.

What must be destroyed is the *substrate* modularity: the parallel identity systems, the independent caches, the window-level truth. Surfaces must be modular. The substrate must be singular.
### What Must Be Unified at All Costs?
In order of criticality:
1. **Identity.** One generational-key system for all canonical objects. No exceptions.
2. **Action grammar.** One typed `AppAction` enum. Every mutation flows through it.
3. **Event log.** One append-only log as the source of truth for state, undo, sync, and agent replay.
4. **Ownership.** Canonical data lives in Rust. Swift holds IDs and session state only.
### What Is the Correct Meaning of Singularity?
Not "one class," not "one module," not "one thread." Singularity means: *one canonical answer* to "what is the state of entity X right now?" That answer lives in the Rust substrate. Every other representation — in a SwiftUI view, in a Metal vertex buffer, in an NSTextStorage, in an agent context window — is a derived, ephemeral projection. Projections can differ in format, resolution, and update cadence. They must not differ in *truth*.
### Realistic Path Toward Extreme Compactness
1. WMO + Rust `opt-level = "z"` + LTO: free 20–40% size reduction, no behavioral change.
2. Python subprocess daemon instead of bundled interpreter: removes 60–100 MB from bundle.
3. Unified Rust static library (one crate compilation output) instead of multiple dylibs: eliminates per-dylib Swift runtime copies.
4. One Metal shader library instead of per-surface shaders: reduces metallib overhead.
5. Dead code elimination pass: after identity unification, many duplicate utility functions become unreachable and are eliminated by LTO.

**Realistic post-optimization binary + assets (excluding Python):** 15–25 MB. This is achievable without feature reduction.
### Which Substrate Architecture Is Best?
**Rust-owned semantic graph with C ABI hot-path FFI, Swift @Observable projections, and Metal for specialized surfaces.** This is the architecture that matches the constraint set precisely: Rust's ownership guarantees for the canonical store, Swift 6's MainActor isolation for UI safety, Metal for GPU-accelerated graph rendering, and AppKit/TextKit 2 for editor-grade text. The GPUI entity model is the closest conceptual reference, adapted for Swift+Rust rather than pure Rust.
### Which FFI Strategy Is Best Long-Term?
**Graduated C ABI.** Use UniFFI during active development of new Rust substrate modules (it is correct and ergonomic). Profile every new call site. When a call site exceeds 1,000 calls/second or 10µs average latency, migrate it to a hand-rolled `#[repr(C)]` ABI. Use `cbindgen` to generate Swift-compatible headers from Rust `#[repr(C)]` struct definitions. This gives the development speed of UniFFI and the performance ceiling of direct C interop where it matters.
### Where Should Python Live?
In a pre-warmed subprocess daemon, reachable via Unix domain socket IPC, invoked only by the agent harness's tool executor, never in the rendering or action paths. Its memory does not overlap with the main process. Its crash does not crash the app. Its startup cost is paid once at background launch time, not on first invocation. Over time, performance-sensitive tools migrate to native Rust, shrinking the daemon's role until it becomes an optional extensibility surface for power users rather than a dependency.
### What Kind of Agentic Harness Architecture Best Fits?
An **event-sourced, graph-contextualized, entity-native harness**: every agent operation is an `AgentAction` appended to the shared event log; tools call into the Rust substrate or the Python daemon; context is assembled from the entity graph (not a flat chat history); task state is a first-class entity observable from any window; and the UI reflects agent state via the same `@Observable` / entity projection mechanism as all other substrate state. The harness is not a wrapper around LLM APIs. It is a first-class citizen of the substrate that happens to interface with LLM APIs as one of its tool types.

The north star: **one machine, many expressions** — and the agent is not bolted onto that machine. The agent is one of its native processes.

---

## References

1. [Implement NSWindow Tabbing with Multiple NSWindowControllers](https://christiantietze.de/posts/2019/07/nswindow-tabbing-multiple-nswindowcontroller/) - After the fiasco of sharing a single NSWindowController among multiple NSWindow instances, one per t...

2. [SwiftUI Performance Deep Dive: Rendering, Identity & Invalidations](https://dev.to/sebastienlato/swiftui-performance-deep-dive-rendering-identity-invalidations-elm) - SwiftUI performance problems rarely come from “slow code”. They come from misunderstanding how Swift...

3. [zed/crates/gpui/README.md at main - GitHub](https://github.com/zed-industries/zed/blob/main/crates/gpui/README.md) - GPUI is a hybrid immediate and retained mode, GPU accelerated, UI framework for Rust, designed to su...

4. [generational_arena - Rust - Docs.rs](https://docs.rs/generational-arena) - A safe arena allocator that allows deletion without suffering from the ABA problem by using generati...

5. [generational-arena - crates.io: Rust Package Registry](https://crates.io/crates/generational-arena) - A safe arena allocator that supports deletion without suffering from the ABA problem by using genera...

6. [macOS and the Responder Chain - Space is Disorienting](http://spaceisdisorienting.com/macos-and-the-responder-chain) - On macOS, the responder chain plays a much bigger role than it does on iOS. On iOS, you typically on...

7. [ResponderChain - CocoaDev](https://cocoadev.github.io/ResponderChain/) - According to Apple: It begins with the first responder in the key window and follows nextResponder l...

8. [How could I do basic memory layout control for bridging Swift to Rust?](https://forums.swift.org/t/how-could-i-do-basic-memory-layout-control-for-bridging-swift-to-rust/83129) - At some point my Swift struct needs to get sent over to Rust, and I'm using the C FFI from both side...

9. [BoltFFI - GitHub](https://github.com/boltffi) - A high-performance multi-language bindings generator for Rust, up to 1,000x faster than UniFFI. Ship...

10. [Introducing Uniffi for React Native: Rust-Powered Turbo Modules](https://hacks.mozilla.org/2024/12/introducing-uniffi-for-react-native-rust-powered-turbo-modules/) - Uniffi for React Native offers a better solution by enabling developers to offload heavy tasks to Ru...

11. [Rendering at 1 million pixels / millisecond with GPUI - Conrad Irwin](https://www.youtube.com/watch?v=sheIOOf-xRo) - ... 2025 Modern computers are *fast*, but modern software rarely pushes it to its limits. We'll talk...

12. [Why Aren't We GUI Yet? - Mikayla Maki - YouTube](https://www.youtube.com/watch?v=rpEU9DNbXA4) - ... 2025 Gold Sponsor, Zed Industries. Presenter ... Rendering at 1 million pixels / millisecond wit...

13. [Streaming changes with Observations | Swift with Majid](https://swiftwithmajid.com/2025/07/30/streaming-changes-with-observations/) - The Observation framework became the main tool for building observable models, replacing the Combine...

14. [@Observable Macro performance increase over ObservableObject](https://www.avanderlee.com/swiftui/observable-macro-performance-increase-observableobject/) - The @Observable macro replaces ObservableObject, @ObservedObject, and @Published. Increase the perfo...

15. [A Deep Dive Into Observation - A New Way to Boost SwiftUI ...](https://fatbobman.com/en/posts/mastering-observation/) - Explore the Observation framework in Swift 5.9: Learn its creation, usage, and benefits for SwiftUI ...

16. [Meet TextKit 2 - WWDC21 – Vídeos - Apple Developer](https://developer.apple.com/br/videos/play/wwdc2021/10061/?time=70) - Meet TextKit 2: Apple's next-generation text engine, redesigned for improved correctness, safety, an...

17. [SwiftUI 2025: What's Fixed, What's Not, and How I Build Apps Now](https://juniperphoton.substack.com/p/swiftui-2025-whats-fixed-whats-not) - Backward compatibility is weak: New SwiftUI APIs often aren't available on older OS versions, requir...

18. [Designing a custom lazy list in SwiftUI with better performance](https://nilcoalescing.com/blog/CustomLazyListInSwiftUI) - Implement a high-performance lazy scrolling list in SwiftUI by efficiently reusing views for smooth ...

19. [Issue 33725: Python crashes on macOS after fork with no exec](https://bugs.python.org/issue33725) - * Why does it only crash on the first invocation of our app? Does getproxies() cache the results som...

20. [Why is python so much slower on MacOS? - Reddit](https://www.reddit.com/r/Python/comments/oouh9a/why_is_python_so_much_slower_on_macos/) - The annoying one (and there is a test for this in that suite confirming it) is that starting python ...

21. [One of my biggest points of criticism of Python is its slow cold start ...](https://news.ycombinator.com/item?id=46230192) - The startup time of a simple .py script can easily be in the 100 to 300 ms range, whereas a C, Rust,...

22. [A closer look at managing Python's memory with PyO3. - gists · GitHub](https://gist.github.com/benkay86/957cf17d2ce2bab3ec47fb92320e75e4) - A closer look at managing Python's memory with PyO3. - pyo3_memory.rs.

23. [Performance: calling overhead · Issue #3827 · PyO3/pyo3 - GitHub](https://github.com/PyO3/pyo3/issues/3827) - I see this 20-40ns overhead in calling PyO3 functions in many scenarios. Also my "baremetal" code is...

24. [Bevy Entity Component System on ESP32 with Rust no_std](https://developer.espressif.com/blog/2025/04/bevy-ecs-on-esp32-with-rust-no-std/) - In this article, we demonstrate how to build an embedded application using Rust no_std and Bevy ECS ...

25. [ECS not just for games :: MRMCD 2025 :: pretalx](https://talks.mrmcd.net/2025/talk/U87GK7/) - I'll explain what Entities, Components, and Systems are good for, and I'll show with the Bevy ECS ho...

26. [TIL Bevy ECS works great outside of games - using it to model circuit ...](https://www.reddit.com/r/rust/comments/1rni81i/til_bevy_ecs_works_great_outside_of_games_using/) - I'm building a code-first PCB design tool in Rust and made an unconventional choice: using Bevy ECS ...

27. [Multiple windows · Issue #45832 · zed-industries/zed - GitHub](https://github.com/zed-industries/zed/issues/45832) - When opening multiple windows across different projects, Zed struggles to manage them independently....

28. [Async Rust — Zed's Blog](https://zed.dev/blog/zed-decoded-async-rust) - From the Zed Blog: In this episode of Zed Decoded, Thorsten and Antonio explore how we use async Rus...

29. [ECS - Bevy Engine](https://bevy.org/learn/quick-start/getting-started/ecs/) - ECS is a software pattern that involves breaking your program up into Entities, Components, and Syst...

30. [Comparing Memory Systems for LLM Agents: Vector, Graph, and ...](https://www.marktechpost.com/2025/11/10/comparing-memory-systems-for-llm-agents-vector-graph-and-event-logs/) - This article compares 6 memory system patterns commonly used in agent stacks, grouped into 3 familie...

31. [Event-Driven Architecture, Event Sourcing, and CQRS: How They ...](https://dev.to/yasmine_ddec94f4d4/event-driven-architecture-event-sourcing-and-cqrs-how-they-work-together-1bp1) - This article will explore what each of these concepts means and how they complement each other in re...

32. [Understanding Event Sourcing and CQRS Pattern | Mia-Platform](https://mia-platform.eu/blog/understanding-event-sourcing-and-cqrs-pattern/) - Event Sourcing is an architectural pattern that tracks changes in a domain by recording them as immu...

33. [5 Zero-Copy Deserialization Techniques in Rust That Will Transform ...](https://techkoalainsights.com/5-zero-copy-deserialization-techniques-in-rust-that-will-transform-your-api-performance-d9edb135b448) - Discover 5 zero-copy deserialization techniques in Rust that eliminate memory allocations and boost ...

34. [Can rkyv do everything that Serde can do? - Rust Users Forum](https://users.rust-lang.org/t/can-rkyv-do-everything-that-serde-can-do/114002) - So in the end serde provides you lot of flexibility but can be a little slower, while rkyv is much m...

35. [Zero-copy FFI structures - The Rust Programming Language Forum](https://users.rust-lang.org/t/zero-copy-ffi-structures/101820) - I am trying to access the C-style vector from Rust (for Rizin's Rust bindings), currently the conver...

36. [Metal Best Practices Guide: Triple Buffering - Apple Developer](https://developer.apple.com/library/archive/documentation/3DDrawing/Conceptual/MTLBestPracticesGuide/TripleBuffering.html) - To avoid creating new buffers per frame and to minimize processor idle time between frames, implemen...

37. [Unexpected memory management behavior · Issue #1056 · PyO3 ...](https://github.com/PyO3/pyo3/issues/1056) - I'm going to the effort of writing a Python extension because I need as fast as possible and predict...

38. [Swift Whole Module Optimization - Use Your Loaf](https://useyourloaf.com/blog/swift-whole-module-optimization/) - The Whole Module Optimization option, new in Xcode 7 removes this limit for Swift code allowing the ...

39. [Compile-time code optimization for Swift and Objective-C](http://dmtopolog.com/code-optimization-for-swift-and-objective-c/) - I tried to get some details about xcode build pipeline, about how the compilers work and where is th...

40. [WWDC22: Improve app size and runtime performance | Apple](https://www.youtube.com/watch?v=bQUIpicLq6o) - Learn how we've optimized the Swift and Objective-C runtimes to help you make your app smaller, quic...

41. [Implementing Single-Key Shortcuts in NetNewsWire - Brent Simmons](https://inessential.com/2019/03/05/implementing_single_key_shortcuts_in_net.html) - A KeyboardShortcut is a KeyboardKey (defined in same file) plus an action string. A KeyboardKey desc...

42. [Obsidian vs Logseq: Choosing Your 2026 Database Strategy](https://www.youtube.com/watch?v=Xs-yult0sW8) - ... Logseq's shift to a database-first architecture is finally solving its long-standing sync and pe...

43. [Craft Review: A Powerful, Native Notes and Collaboration App](https://www.macstories.net/reviews/craft-review-a-powerful-native-notes-and-collaboration-app/) - Bear offers an elegant Markdown experience and powerful note linking features. Agenda takes a unique...

44. [Bear: Markdown Notes - App Store - Apple](https://apps.apple.com/us/app/bear-markdown-notes/id1091189122) - Bear is a beautiful, powerfully simple Markdown app to capture, write, and organize your life. Take ...

45. [Optimize for variable refresh rate displays - WWDC21 - Videos](https://developer.apple.com/videos/play/wwdc2021/10147/) - Learn techniques for pacing full-screen game updates on Adaptive Sync displays in macOS, and find ou...

46. [How to use CAMetalLayer with an NSView? - Stack Overflow](https://stackoverflow.com/questions/59112245/how-to-use-cametallayer-with-an-nsview) - In AppKit, you make the view layer backed by setting the view's wantsLayer property. The app explici...

47. [What's new in SwiftUI - WWDC25 - Videos - Apple Developer](https://developer.apple.com/videos/play/wwdc2025/256/) - Learn what's new in SwiftUI to build great apps for any Apple platform. We'll explore how to give yo...

48. [Build an AppKit app with the new design - WWDC25 - Videos](https://developer.apple.com/videos/play/wwdc2025/310/) - We'll dive into key changes to tab views, split views, bars, presentations, search, and controls, an...

49. [First look at the new Rust GPUI framework from Zed! - YouTube](https://www.youtube.com/watch?v=OHU-Y93eCs8) - The framework allows us to build UIs that are rendered ... Rendering at 1 million pixels / milliseco...

50. [pyo3 large memory footprint when making lists · Issue #872 - GitHub](https://github.com/PyO3/pyo3/issues/872) - Lists created from returned pyo3 calls appear to have nearly twice the memory footprint as native py...

51. [Your Agent Needs a Harness, Not a Framework - Inngest Blog](https://www.inngest.com/blog/your-agent-needs-a-harness-not-a-framework) - The point: the tools story for AI agents is the same as any other software. Use existing libraries. ...

52. [Zep: A Temporal Knowledge Graph Architecture for Agent Memory](https://arxiv.org/html/2501.13956v1) - We introduce Zep, a novel memory layer service for AI agents that outperforms the current state-of-t...

53. [Context Graph vs. Knowledge Graph - TrustGraph](https://trustgraph.ai/guides/key-concepts/context-graph-vs-knowledge-graph/) - A context graph is a knowledge graph—but one purpose-built for AI. Learn how ontologies, graph stora...

54. [Questions about Swift 6 Concurrency - Using Swift](https://forums.swift.org/t/questions-about-swift-6-concurrency/82045) - I'm in the process of migrating a reasonably large (60K LOC) Swift app to Swift 6 and have a few que...

55. [Effective context engineering for AI agents - Anthropic](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents) - Our overall guidance across the different components of context (system prompts, tools, examples, me...

56. [Synking all the things with CRDTs: Local first development](https://dev.to/charlietap/synking-all-the-things-with-crdts-local-first-development-3241) - This blog post should serve as a good primer for anyone looking to get into local first development ...

57. [Advanced NSView Setup with OpenGL and Metal on macOS](https://metashapes.com/blog/advanced-nsview-setup-opengl-metal-macos/) - The solution was to completely ditch NSOpenGLView and switch to a layer-backed NSView with an NSOpen...

