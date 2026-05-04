# The unified substrate: an architectural manifesto for native cognitive software

**The singular thesis is this: a 250,000-line macOS app built on Swift 6, Rust, Metal, and Python cannot become a great cognitive tool by adding more modules. It becomes one by discovering the substrate those modules were always trying to be.** The path is not consolidation for consolidation's sake, nor is it the false singularity of a monolith. It is the recognition that windows are apertures into a shared semantic world, that state is a graph not a tree, that rendering is projection not construction, and that compactness emerges from architectural coherence, not file-size tricks. The recommended architecture is a Rust-owned canonical core using an entity-handle state model inspired by GPUI, exposed through a tiered FFI strategy (custom C ABI for hot paths, UniFFI for cold paths), with Metal-backed rendering through a single scene-graph substrate, Swift as a thin orchestration and platform-integration shell, Python relegated to an isolated subprocess tool runtime, and an event-sourced command grammar that unifies undo, agentic actions, and multi-window synchronization into one mechanism. The realistic binary target is **10–15 MB without Python, 20–25 MB with it**. Five megabytes is fantasy for this stack. The realistic migration timeline is 6–9 months of phased substrate extraction, not a rewrite.

---

## 1. Manifesto: why unified substrate, why now

### Fragmented modularity is a hidden tax

Every module boundary in a large native app imposes a tax. Not just the obvious costs—duplicate type definitions, serialization overhead, state synchronization bugs—but deeper structural costs that compound silently. When the notes sidebar owns its own state store, the graph view maintains a parallel model, settings live in a separate world, and each window constructs its own reality from scratch, the app pays this tax on every interaction. **A user renames a note and the graph view doesn't update until a refresh. A preference changes and three surfaces poll for it independently. An undo operation reverses one surface's state but not another's.** These are not bugs in the traditional sense. They are symptoms of architectural fragmentation: the absence of a shared semantic substrate.

The fragmentation tax scales superlinearly with surface count. Two surfaces sharing state through notifications is manageable. Six surfaces with bidirectional state dependencies—notes, graph, settings, sidebar, chat, landing—creates **O(n²) synchronization complexity**. Each new surface doesn't add linearly to maintenance burden; it multiplies it. This is why large apps feel increasingly sluggish and inconsistent as they grow. Not because any single module is poorly written, but because **the space between modules is where coherence goes to die**.

### False singularity is equally dangerous

The opposite error—collapsing everything into a monolith—destroys the modularity that lets surfaces evolve independently. A graph view has fundamentally different rendering requirements than a text editor. Settings panels need different invalidation strategies than real-time canvases. Forcing all surfaces through identical pipelines produces the worst of both worlds: the rigidity of a monolith with the incoherence of fragmented modules.

### The correct answer: modular surfaces over a unified core

The goal is **one semantic world, many projected surfaces**. The core owns identity, state, relationships, and the grammar of actions. Surfaces are projections—lenses that view, filter, and interact with the shared world according to their own visual and interaction logic. A note in the editor and a node in the graph view are not two objects synchronized by messages. They are **one entity seen through two apertures**.

This is precisely how game engines work. Unity and Unreal maintain a single World. Editor viewports, game cameras, and debug overlays all project different views of that same world. No viewport owns any entity; the World does. Viewports define what to show and how. Zed's GPUI takes this further: all application state is owned by a single `App` context, and views are entities that implement a `Render` trait to project themselves. The `Entity<T>` handle is an inert identifier—**it does not own state**. Only the central context does.

### Windows are apertures, not worlds

On macOS, the NSDocument architecture already encodes this principle. Apple's documentation is explicit: "An NSDocument object should not contain or require the presence of any objects that are specific to the application's user interface." The document is the model-controller; window controllers are view-controllers that project it. But most modern SwiftUI apps violate this by entangling window state with canonical state, creating what amounts to separate kingdoms per window.

The correct model: **every window is a viewport with its own session state (scroll position, zoom level, cursor) but no canonical state.** Canonical state—the knowledge graph, note content, tag relationships, user preferences—lives in exactly one place. A mutation anywhere propagates everywhere through observation, not notification spaghetti.

### Identity, action grammar, and ownership must be unified

If a note has one identity in the sidebar, another in the graph, and a third in the editor, you do not have one app. You have three apps wearing a trench coat. **Unified identity** means every entity in the system has exactly one canonical identifier—an entity ID, a generational index, a typed handle—that is the same regardless of which surface displays it. **Unified action grammar** means every mutation flows through a single command system—`CreateNote`, `UpdateContent`, `LinkNotes`, `ChangeTag`—that is validated, logged, undoable, and observable by all surfaces. **Unified ownership** means the Rust core owns the canonical state, Swift holds projection handles, and Metal receives render commands—never the reverse.

### Compactness is semantic compression, not file-size reduction

A 15 MB app that maintains one coherent world-model, one render pipeline, one text system, one event log, and one identity space is more compact than a 10 MB app with five duplicated subsystems that happen to be individually smaller. **Compactness is the ratio of capability to mechanism.** Architectural compactness—fewer concepts, fewer boundaries, fewer translation layers—produces runtime compactness (less memory, faster launch, less idle overhead) as a natural consequence. The goal is not to strip symbols until the binary is small. It is to build a system where there is nothing left to remove.

---

## 2. Architectural options: five substrate patterns analyzed

### Option A: Rust-owned entity graph with Swift projection shells

**Ontology.** All application state lives in a Rust-side entity store modeled after GPUI's `App` context. Entities are typed handles (`Entity<Note>`, `Entity<Link>`, `Entity<Tag>`, `Entity<ViewState>`). Components are plain Rust structs. Systems are Rust functions that query and mutate the store. Swift receives entity handles across FFI and uses them to drive SwiftUI/AppKit views.

**Ownership.** Rust owns everything canonical. Swift holds borrowed projections via handle IDs (u64 generational indices). The lease pattern from GPUI prevents double-mutable-borrow violations: state is temporarily removed from the store during mutation callbacks, then restored. Effects are queued, never dispatched reentrantly.

**Window model.** Each NSWindow has a thin Swift controller that holds a window-entity handle pointing into the Rust store. Session state (scroll, zoom, cursor) is stored as Rust components on the window entity. Canonical state is never duplicated per-window.

**Event/action model.** Commands are Rust enum variants submitted to an event queue. The queue flushes synchronously on the main thread. Observers fire after mutations complete, triggering view invalidation. This matches GPUI's effect queue exactly—no reentrancy bugs, deterministic ordering.

**Rendering.** Rust generates a flat scene (display list of primitives: quads, glyphs, paths, shadows) and submits it to Metal through shared `MTLBuffer` with `.storageModeShared` on Apple Silicon. Swift/AppKit manages NSWindow lifecycle and CAMetalLayer attachment.

**FFI/ABI.** Custom C ABI for the hot path (render commands, input events, entity queries). UniFFI for cold paths (settings, configuration, infrequent operations). Entity handles cross as u64; strings are interned to u32 symbol IDs. Buffer pointers shared via arena-scoped spans.

**Binary cost.** Rust static library ~3–5 MB (stripped, LTO, -Oz, panic=abort). Swift shell ~2–4 MB. Metal shaders ~0.2 MB. **Total ~6–10 MB** without Python. This is the most compact viable architecture.

**Migration difficulty.** High. Requires extracting all canonical state from Swift into Rust. But the migration can be incremental: start with the knowledge graph and note content, then progressively move UI state.

**Verdict.** This is the recommended architecture. It matches the proven pattern from the most performance-sensitive native apps being built today (Zed), solves the multi-window singularity problem at the architectural level, and produces the most compact runtime.

### Option B: ECS-like substrate with semantic components

**Ontology.** Full Entity-Component-System modeled after Bevy. Notes, links, tags, UI widgets, and windows are all entities. Properties are components: `Content`, `Position2D`, `Visibility`, `EditingState`, `LinkedTo`. Behavior lives in systems: `SearchIndexSystem`, `BacklinkResolutionSystem`, `AutosaveSystem`, `UIRenderSystem`.

**Ownership.** A single `World` struct owns all component storage. Sparse-set storage (like EnTT) for the heterogeneous entity population typical of a knowledge app. Generational indices for safe handle invalidation across undo/redo.

**Key advantage.** ECS enables "one world, many views" natively. The graph view is a system that queries `Position2D + LinkedTo + Visibility`. The notes list is a system that queries `Content + Title + ModifiedAt`. Same data, different projections, zero synchronization needed.

**Key risk.** ECS is an unfamiliar paradigm for most Swift/macOS developers. Tooling is immature for non-game contexts. The Leafwing Studios analysis confirms there's no fundamental impedance mismatch with UI, but the practical challenge is integration with SwiftUI/AppKit's own paradigms.

**FFI consequence.** Component storage can be exposed as `#[repr(C)]` arrays of structs, enabling zero-copy reads from Swift via `UnsafeBufferPointer`. Query results are pointer+length spans valid for the system's execution scope.

**Binary cost.** Similar to Option A. ECS framework code adds ~100–200 KB over a hand-rolled entity store.

**Migration difficulty.** Very high. Requires rethinking the entire data model. Better suited for a greenfield rewrite than incremental migration.

### Option C: Event-sourced command graph with projection layers

**Ontology.** All state changes are expressed as an append-only event log. Current state is a materialized view derived by replaying events (with periodic snapshots for performance). Commands are validated intents; events are immutable facts.

**Key advantage.** Undo/redo becomes trivial—decrement the history pointer. Version history is free. Audit trail for agent actions is built in. Event streams can feed into CRDT layers for future sync/collaboration.

**Key risk.** Querying current state requires maintaining materialized views, which must be kept in sync. Schema evolution of events over app versions is complex. Martin Fowler's own analysis notes that "event sourcing introduces a number of problems that it does not itself solve."

**Rendering model.** Events generate typed diffs that flow to a diff-driven UI: only changed fields trigger re-renders. This is architecturally elegant but requires careful implementation to avoid the "diff computation is more expensive than re-rendering" trap for small state.

**FFI consequence.** Events are `#[repr(C)]` structs in a ring buffer. Swift reads from the ring buffer lock-free (SPSC pattern with atomic read/write heads). True zero-copy for the event stream.

**Binary cost.** Similar to Options A/B. Event log storage adds disk overhead but not binary size.

**Best as.** A layer within Option A, not a standalone architecture. Event sourcing for the command/mutation system; entity store for current-state queries.

### Option D: Actor-isolated semantic core with projection layers

**Ontology.** Uses Swift 6's actor model as the primary concurrency primitive. A `KnowledgeActor` owns the canonical graph. A `SearchActor` owns the index. A `PersistenceActor` owns disk I/O. Views interact through async message passing.

**Key advantage.** Leverages Swift 6's native concurrency model. `@MainActor` for UI state, custom actors for background work. Compiler enforces thread safety.

**Key risk.** Actor message passing introduces latency between mutation and observation. Swift actors are not zero-cost—each actor hop involves task scheduling overhead. For a UI that needs <4ms frame times, actor isolation can introduce jitter. Also, **double synchronization** when combining Swift actors with Rust mutexes (UniFFI requires `Sync + Send`) risks priority inversion or deadlock.

**Rendering model.** SwiftUI views observe `@Observable` model objects on `@MainActor`. Rust provides computed results via async bridge. Metal rendering for specialized surfaces (graph, canvas) via `NSViewRepresentable`.

**Binary cost.** Slightly larger than Option A due to Swift concurrency runtime overhead. Rust binary can be smaller if more logic stays in Swift.

**Best as.** The Swift-side orchestration layer atop a Rust-owned core (Option A + D hybrid). Actors for scheduling and isolation; Rust for data ownership and computation.

### Option E: AppKit/SwiftUI hybrid with stronger substrate laws

**Ontology.** Keep the existing architecture but enforce strict substrate laws: one `@Observable` KnowledgeStore shared via environment, all mutations through a command protocol, all surfaces observe (never own) canonical state.

**Key advantage.** Lowest migration cost. Uses familiar patterns. SwiftUI's property-level observation (`@Observable`, not `ObservableObject`) provides fine-grained invalidation—only views reading a changed property re-render.

**Key risk.** SwiftUI performance cliffs are real and documented. Alin Panaitiu's Grila calendar hit multi-second delays rendering 365 views on an M1 Max. `@Binding` propagation causes sibling re-renders. NavigationSplitView has been "a constant pain point." For a complex app with hundreds of views across multiple windows, SwiftUI's internal "graph updating code" becomes the heaviest stack trace. The Fatbobman bug—`@State` in root views sharing identity across all windows—was only fixed in macOS 14.5.

**Rendering model.** SwiftUI for most surfaces. Metal via `NSViewRepresentable` for graph/canvas. This creates two rendering worlds that must be kept visually coherent—a maintenance burden.

**Binary cost.** Potentially the largest. SwiftUI's protocol witness tables, generic specialization, and reflection metadata bloat Swift binaries. Multiple rendering subsystems duplicate code.

**Best as.** A transitional architecture during migration toward Option A. Not a long-term destination.

---

## 3. Reference systems and why they matter

**Zed (GPUI) is the most relevant reference system.** It proves that a Rust-owned entity store, custom Metal rendering with primitive-specific shaders, a hybrid immediate/retained declarative API, and an effect-queue architecture can produce 120fps UI performance with deterministic memory behavior. Key technical details: the entity lease pattern (temporarily removing state from the store for mutation callbacks) elegantly solves Rust's borrow-checker challenges. The glyph atlas with 16 sub-pixel variants enables GPU-accelerated text rendering at near-memory-bandwidth speeds. Three-phase rendering (Prepaint → Paint → Present) with Taffy flexbox layout and view-level dirty tracking provides the right abstraction layers. **GPUI's recent migration from Blade to wgpu shows the value of renderer abstraction even within a custom framework.**

**Xi-editor is the most important cautionary tale.** Raph Levien's retrospective is devastating in its honesty: "I now firmly believe that the process separation between front-end and core was not a good idea." Async between UI and core made scrolling take months to implement. Swift's JSON deserialization was "shockingly slow." Serde bloated the Rust binary to 9.3 MB. The lesson: **put the core and UI in the same process, use a synchronous main-thread update loop, and avoid serialization on the hot path.** Plugin isolation via separate processes (like LSP) is fine; core/UI separation is not.

**Bevy ECS validates data-oriented composition for complex software.** Its sparse+archetype hybrid storage, automatic parallel scheduling from system signatures, Observer pattern for push-based reactivity, and new Relations system for entity-to-entity edges directly address the "one world, many views" need of a knowledge app. The Leafwing Studios analysis confirms "no fundamental impedance mismatch between ECS and GUIs."

**Salsa (rust-analyzer) proves incremental computation at scale.** Its durability system (queries tagged as volatile/normal/durable) reduces incremental rebuild overhead from 300ms to near-zero for no-op changes. The "early cutoff" optimization—if a re-executed query produces the same result, downstream queries skip—prevents cascading re-computation. The rust-analyzer invariant that "typing inside a function body never invalidates global derived data" shows how to design computation boundaries for editing workloads.

**Figma's renderer proves custom rendering at scale.** They describe their architecture as "a browser inside a browser—own DOM, compositor, text layout engine." Their tile-based GPU renderer handles masking, blurring, blend modes, and nested layer opacity. The recent WebGL→WebGPU migration (via Dawn) parallels considerations for Metal abstraction.

---

## 4. Zero-copy architecture and memory discipline

### Where zero-copy is real

**Numeric buffers and `#[repr(C)]` struct arrays** are the sweet spot. Pass a `*const f32` with a length across the Swift-Rust boundary and both sides read the same memory. For render commands, define `#[repr(C), align(16)]` structs with fixed-size fields (`u32`, `f32`, `[f32; 16]`)—no pointers, no variable-length data, no ARC. Both Swift (via `UnsafeBufferPointer`) and Rust read directly. This is proven in Metal workflows where `MTLBuffer.contents()` returns a raw pointer both sides access.

**Metal shared buffers on Apple Silicon are genuinely zero-copy between CPU and GPU.** With `.storageModeShared`, the same physical memory is accessible from both CPU code (Swift/Rust) and GPU shaders. The pattern: Swift creates `MTLBuffer`, passes `contents()` pointer to Rust via C FFI, Rust writes compute results directly into the buffer, Swift submits the buffer to a Metal command encoder. **No copies at any stage.** The LambdaClass team demonstrated a full Rust→Metal compute pipeline using `metal-rs` with this pattern.

**Arena-scoped borrowed spans** provide safe zero-copy windows. The pattern: Rust creates a `bumpalo::Bump` arena at the start of a processing phase (frame, query, import). All intermediate data is allocated in the arena. Pointers into the arena are passed to Swift as `Span { ptr, len }` structs. Swift reads through `UnsafeBufferPointer` for the duration of the phase. When the phase completes, the arena drops, invalidating all spans. The lifetime is enforced by protocol, not by the type system across FFI—but the protocol is simple and auditable.

**Ring buffers for event streaming** achieve lock-free zero-copy. A `#[repr(C)]` ring buffer with `AtomicU32` read/write heads enables single-producer (Rust) single-consumer (Swift) communication without locks. Fixed-size `#[repr(C)]` event entries are written by Rust and read by Swift through the same memory. The TantalusPath team evolved to exactly this pattern after finding UniFFI callbacks too slow.

### Where zero-copy is ideology, not reality

**Strings cannot be zero-copy between Swift and Rust.** This is a hard constraint, not an optimization opportunity. Swift's `String` has no zero-copy initializer from a byte buffer—`bytesNoCopy` is deprecated and documented as unsupported. Every string crossing requires an allocation and memcpy. The swift-bridge documentation is explicit: "There is no zero-copy way to construct a Swift String from a byte buffer." The correct response is not to fight this but to **design around it**: intern strings to u32 symbol IDs, pass IDs across the boundary, resolve lazily on each side. A Rust-side `HashMap<String, u32>` string interner eliminates string copying on hot paths entirely.

**Swift Array ↔ Rust Vec cannot be zero-copy** due to different memory management models (CoW + ARC vs. owned). The `withUnsafeBufferPointer` closure gives temporary access but the pointer must never escape. This is where BoltFFI and swift-bridge offer meaningful improvement over UniFFI—they support reference semantics for compatible types—but the fundamental constraint remains.

**Any type requiring Swift ARC on the receiving side must be copied.** If Swift needs to own data (store it in a `@State`, pass it to a SwiftUI view), it must live in ARC-managed memory. Cross-FFI handles should be `@unchecked Sendable` wrappers around opaque pointers, not materialized Swift objects.

### Where strategic copying is the correct choice

**Complex state snapshots** should be serialized once via FlatBuffers (not rkyv, despite rkyv's superior single-language performance, because FlatBuffers has official Swift codegen) and read many times. The serialization cost is amortized over all reads. For a knowledge graph snapshot sent to Swift for rendering, this means one FlatBuffers serialize on state change, zero-copy field access thereafter.

**Infrequent configuration changes** should use UniFFI. Its ~1.4μs per-call overhead is irrelevant for operations that happen once per user action. The ergonomics and safety justify the cost. Reserve custom C ABI work for measured bottlenecks.

### The tiered FFI strategy

- **Hot path (>1000 calls/sec)**: Custom C ABI with `#[repr(C)]` structs, `extern "C" fn`, cbindgen-generated headers. Arena-scoped spans, ring buffer events, shared MTLBuffers.
- **Warm path (10–1000 calls/sec)**: swift-bridge for typed reference semantics with minimal overhead.
- **Cold path (<10 calls/sec)**: UniFFI for maximum ergonomics and safety. Settings, configuration, lifecycle events.

### Swift 6 concurrency traps

UniFFI-generated Swift classes require `Sync + Send` on the Rust side and add their own synchronization. Combined with Swift 6's actor isolation, this creates **double synchronization**: Swift actor scheduling + Rust mutex locking. This can cause priority inversion when a Rust lock is held across a Swift actor suspension point. The mitigation: use `nonisolated` functions for Rust FFI calls, avoid crossing actor boundaries with Rust locks held, and wrap FFI handles as `@unchecked Sendable` with manual documentation of thread-safety guarantees.

---

## 5. Binary size and compactness: the realistic picture

### What actually contributes to binary size

**Swift metadata is the largest silent contributor.** Nearly half the size of `libswiftCore.dylib` is string tables for mangled symbol names. Protocol witness tables accumulate with protocol-oriented design. Reflection metadata includes type descriptors and field descriptors. **Mitigation**: `strip -rSTx` achieves 25–30% reduction; `-Xfrontend -disable-reflection-metadata` removes reflection data; Whole Module Optimization enables cross-file dead code elimination. With all mitigations, Swift code size becomes comparable to Objective-C.

**Rust monomorphization is the dominant Rust-side factor.** Raph Levien's analysis of xi-editor found serde was the single biggest source of bloat. Every generic function is duplicated for each concrete type. `core::fmt` is notoriously heavy—even a simple `println!` pulls in substantial formatting infrastructure. **Concrete measurements** (Shane Osbourne, 2024): default release 18 MB → stripped 14 MB → `-Oz` 12 MB → LTO 8.1 MB → `codegen-units=1` 7.9 MB → `panic="abort"` **7.0 MB**. That's a 61% reduction from disciplined profile configuration alone.

**UniFFI's generated scaffolding** adds ~50–100 KB for a moderately complex interface. Per exported type: ~1–3 KB of Swift wrapper code. Per function: ~200–500 bytes. For a 250K-line app with potentially hundreds of bridge points, this could reach 0.5–1 MB. A custom C ABI is **10–50x thinner** for the bridging layer.

**Cross-language LTO between Swift and Rust is not possible** today. Apple's custom LLVM fork and Rust's own LLVM revision are incompatible. FFI calls cannot be inlined across the boundary. This means the C ABI boundary remains opaque to optimizers on both sides. **Design consequence**: keep the boundary coarse-grained. Do heavy work on one side, pass results across. Fewer, larger function calls—not many small ones.

### The realistic budget

| Component | Optimistic | Notes |
|-----------|-----------|-------|
| Swift binary (stripped, -Osize, WMO) | 3–5 MB | For ~100K lines of Swift |
| Rust static library (stripped, -Oz, LTO, panic=abort) | 2–4 MB | For ~100K lines of Rust |
| FFI bridge layer | 0.1–0.3 MB | Custom C ABI preferred |
| Metal shaders (.metallib) | 0.1–0.3 MB | Single unified pipeline |
| Bundled assets | 0.5–1 MB | Icons, minimal fonts |
| **Total without Python** | **6–11 MB** | Aggressive but achievable |
| Python runtime (aggressively stripped) | 15–20 MB | Minimal stdlib + lib-dynload |
| **Total with Python** | **21–31 MB** | Realistic minimum |

**Is 5 MB achievable?** No. Not for 250K lines across three languages with Metal shaders. Even a pure C application of this complexity would struggle to fit in 5 MB. **10–15 MB without Python** is ambitious and achievable with disciplined optimization. This would place the app in the same class as Bear (~15–20 MB) and iTerm2 (~20 MB)—the most compact pro-grade native macOS apps shipping today.

**Architectural compactness matters more than byte-level optimization.** One unified render pipeline versus separate 2D/3D/text rendering subsystems saves 2–5 MB and eliminates duplicated shader infrastructure. One state management system versus per-surface stores eliminates redundant type definitions and synchronization code. One text system versus TextKit + CoreText + custom saves entire framework dependencies.

---

## 6. Multi-window singularity

### The canonical architecture

One `@Observable` KnowledgeStore (or Rust-side entity store) placed in the SwiftUI environment at the App level. All windows read from and write to this store. Property-level observation ensures only views reading a changed property re-render—not all views in all windows. This is the critical advantage of `@Observable` over the older `ObservableObject` pattern.

**Session state versus canonical state must be explicitly separated.** Canonical state (knowledge graph, note content, tags, preferences, undo history) lives in exactly one place—the shared store. Session state (scroll position, zoom level, cursor position, expanded/collapsed sections, local search query, navigation stack) lives in `@State` on each window's root view. Never share session state across windows. Never put canonical state in per-window storage.

### Focus routing across windows

`FocusedValue` is SwiftUI's reinvention of AppKit's responder chain. It enables the active window to expose actions and data to scene-level commands (menu bar, keyboard shortcuts). The pattern: define a `FocusedValueKey` whose value is an action closure; the active window provides the closure via `.focusedSceneValue()`; menu commands read it via `@FocusedValue`. When no window provides the value, menu items auto-disable. This replaces the responder chain pattern cleanly.

For a knowledge management app: each surface type (notes editor, graph canvas, chat, settings) provides its own set of focused values. The menu bar dynamically reflects the capabilities of the frontmost window. A "Delete Note" command is available when a notes window is active; a "Recalculate Layout" command appears when the graph is active. **No conditional logic in the menu—the focused value system handles it automatically.**

### How pro apps validate this pattern

Xcode, the most complex macOS app, uses NSDocument architecture where the workspace is the document and windows are views. Multiple window controllers can project the same workspace. BBEdit uses 29 years of refined AppKit responder chain routing. Nova treats each window as a project workspace with panes as projections. The common pattern: **one window = one workspace context; panes within windows rather than many separate windows; the document IS the model**.

### The graph-as-projection principle

The graph view and the notes editor are different projections of identical data. The graph view queries entities with `Position2D + LinkedTo + Visibility` components and renders them as nodes and edges. The notes editor queries entities with `Content + Title + EditingState` and renders them as rich text. **Editing a note title in the editor updates the node label in the graph with zero synchronization code—both read the same entity.** Layout positions in the graph are session state (per-graph-window); the existence and content of the note is canonical state (shared).

---

## 7. Rendering and UI substrate

### The two-tier scene graph

The recommended rendering architecture separates concerns into two layers. The **logical tree** holds components, views, layout nodes, and identity. It is retained, diffable, and persists across frames. The **render tree** is a flat display list of GPU primitives (quads, glyphs, paths, shadows, images) regenerated per dirty subtree and submitted to Metal. This matches GPUI's Scene struct—layers containing vectors of typed primitives, drawn via instanced draw calls.

**Primitive-specific Metal shaders** (as proven by GPUI) dramatically outperform general-purpose 2D graphics libraries for text-heavy productivity apps. SDF-based rounded rectangles, Evan Wallace's closed-form shadow technique, and glyph atlas rendering each get their own optimized shader. All instances of each primitive type are drawn in a single instanced draw call. At 120fps on ProMotion displays, GPUI achieves sub-4ms frame times with this approach.

### Text rendering: bypass TextKit 2

TextKit 2 has been shipping for four-plus years and remains deeply problematic. Viewport layout stops short. Extra line fragment layout is broken. Regressions occur across OS versions. Marcin Krzyzanowski (STTextView author) concludes: "TextKit 2 might not be the best tool for text layout, especially for text editing UI." The CodeEdit team built their own CoreText-based text view that "loads million-line files in milliseconds, supports multiple cursors, lazy layout."

The recommended approach for a knowledge management app: **use CoreText for text shaping and glyph metrics** (it handles Unicode, BiDi, ligatures, and kerning correctly), then **render via Metal glyph atlas** (as GPUI does). Glyph rasterization happens via CoreText/CoreGraphics on CPU; results are packed into a GPU texture atlas using bin-packing (etagere algorithm). Sub-pixel positioning with up to 16 variants per glyph ensures native-quality rendering. The key optimization from GPUI: share memory between CoreGraphics and Metal by creating an `MTLBuffer` with `newBufferWithBytesNoCopy:` and using it as backing for a `CGBitmapContext`, eliminating CPU→GPU texture uploads entirely.

### Accessibility is non-negotiable

Custom GPU-rendered UI means VoiceOver has zero visibility into your UI. You must manually construct an accessibility tree using `NSAccessibilityElement` instances for every interactive element, with roles, labels, actions, and hierarchy. Cache accessible elements for as long as their UI element is visible. Post `NSAccessibilityPostNotification` when content changes. Implement `accessibilityHitTest:` for spatial queries. **Design the accessibility tree first, not as an afterthought—it constrains the element identity system.**

### How far custom rendering should go

Custom-render: text editors, graph/canvas views, scrolling regions, animations, themed UI elements. Keep native: NSMenu system menu bar, NSOpenPanel/NSSavePanel file dialogs, system alerts. The pragmatic boundary: **settings panels can go either way** (native feels more Mac-like; custom ensures visual coherence), but IME interaction via NSTextInputClient should use a native overlay for complex input methods. Zed demonstrates the right boundary—"a fully-native AppKit NSApplication" that uses native window management and menus but renders all content areas custom.

---

## 8. Python runtime strategy

### The decisive analysis

Embedding Python adds **15–25 MB** to the app bundle (libpython + stripped stdlib + lib-dynload). It adds ~15–25 MB RSS for an idle interpreter. It introduces the GIL, which blocks concurrent Python execution (free-threaded Python 3.13/3.14 is experimental with 5–40% single-thread overhead). It creates a crash coupling: Python segfault = app crash. It complicates sandboxing (in-process Python sandboxing is fundamentally broken; RestrictedPython handles only a restricted subset).

**The question is not whether to embed Python but whether Python is needed at all.** For a native knowledge management app:

- **ML inference**: Rust has candle, ort (ONNX Runtime), and Apple's MLX has Swift bindings. No Python needed.
- **Data processing**: Rust's polars and serde ecosystem is comprehensive. No Python needed.
- **Scripting/plugins**: JavaScriptCore ships with macOS at zero additional binary cost. Lua is ~200 KB. Either is a better embedding target than Python's 15+ MB.
- **MCP tool servers**: MCP is a JSON-RPC protocol implementable in any language. The official Rust SDK exists.

**If Python is genuinely needed** (for specific libraries with no Rust equivalent): use the **isolated subprocess model**, not embedding. Run Python in a child process communicating via stdin/stdout JSON-RPC (the Sublime Text `plugin_host` pattern). This provides OS-level crash isolation, sandbox-profile-based security, GIL independence, and the ability to use any Python version/packages without bundling. The subprocess model adds ~30–100ms latency per spawn but <1ms for subsequent calls over a persistent connection.

**Recommended architecture**: No embedded Python. Native Rust/Swift for all core functionality. JavaScriptCore for user scripting (zero binary cost on macOS). MCP subprocess servers for Python-dependent tools, spawned on demand, communicating via stdio transport. This saves 15–25 MB in binary size and eliminates an entire category of runtime complexity.

---

## 9. Agentic harness as native substrate

### The agent loop belongs in Rust

The agent orchestration loop—receive intent, build context, call LLM, parse tool calls, execute tools, observe results, loop or return—must be a Rust library, not a Python framework running inside your app. This gives you type-safe tool definitions, zero-cost abstractions for the hot path (context assembly, graph traversal), and no GIL contention during tool execution.

### MCP as the tool integration layer

Implement the app as an **MCP host** with a Rust MCP client (using the official `modelcontextprotocol/rust-sdk`). This connects to the growing ecosystem of MCP servers—file system, web search, database query, Python script runner—via stdio or HTTP transport. Critically, also **expose the app as an MCP server**: `search_notes(query)`, `get_note(id)`, `create_link(from, to, type)` become tools that external AI systems (Claude Desktop, Cursor) can use to interact with the knowledge base.

### Graph-aware context is the killer advantage

A knowledge management app's graph IS the agent's long-term memory. Context window construction should walk the graph from the user's current focus: current note → 1-hop related notes (backlinks, forward links) → summaries of 2-hop neighbors → recent agent interactions (stored as graph nodes themselves) → relevant tool result cache. This context is assembled natively in Rust with graph traversal, not by calling Python scripts.

### Event-sourced action ledger

Every agent action produces an immutable event: `{ id, timestamp, event_type, agent_id, payload, parent_event, confidence }`. Event types: thinking, tool_call, tool_result, text_stream, error, permission_request. This ledger feeds the UI (showing what the agent is doing), enables replay/audit, and provides action recipes (replayable sequences that can be saved as templates).

### UI reflection through typed event streams

Agent state flows to SwiftUI via a typed event stream: `AgentUIEvent` enum with cases for `.thinking(String)`, `.toolCall(name, args)`, `.toolResult(summary)`, `.textStreaming(token)`, `.statusChange(AgentStatus)`, `.requestingPermission(action)`. The UI renders these natively—no HTML, no webview. Progressive disclosure: thinking indicator → expand to show tool calls → full detail on tap. Streaming tokens arrive in real-time via async streams.

### Permission tiers

Read-only operations (search, read notes, analyze) execute without confirmation. Write-with-notification operations (create note, add link) execute and show a notification. Write-with-confirmation operations (delete, bulk changes) pause for explicit approval. Restricted operations (file system access, network calls, code execution) require per-invocation consent. Users can adjust these tiers as trust builds.

### Local-first LLM with API escalation

Use local models via MLX on Apple Silicon for routine operations (small context, simple tool calls). NativeMind's benchmarks show Qwen3 4B achieving **65% task success rate**, matching GPT-4o mini. Route complex reasoning tasks to Claude or GPT-4 via API when local model confidence is low. Build context locally; send only necessary fragments to the API. This preserves privacy for most interactions while enabling full capability when needed.

---

## 10. Recommended architecture for Swift 6 + Rust + Metal + Apple Silicon

### The substrate stack

```
┌─────────────────────────────────────────────────┐
│   macOS Platform Shell (Swift 6)                 │
│   NSApplication, NSWindow, NSMenu, CAMetalLayer  │
│   @Observable projections, FocusedValue routing   │
├──────────────────┬──────────────────────────────┤
│   FFI Boundary   │  Hot: Custom C ABI + arena    │
│                  │  Warm: swift-bridge            │
│                  │  Cold: UniFFI                  │
├──────────────────┴──────────────────────────────┤
│   Rust Canonical Core                            │
│   ┌──────────────────────────────────────────┐  │
│   │  Entity Store (GPUI-inspired)             │  │
│   │  - Generational handles                   │  │
│   │  - Lease pattern for mutation             │  │
│   │  - Effect queue (no reentrancy)           │  │
│   │  - Observer/subscription system           │  │
│   ├──────────────────────────────────────────┤  │
│   │  Command / Event System                   │  │
│   │  - Typed command enum                     │  │
│   │  - Validation → Event production          │  │
│   │  - Append-only event log                  │  │
│   │  - Undo/redo via history index            │  │
│   │  - Ring buffer for Swift consumption      │  │
│   ├──────────────────────────────────────────┤  │
│   │  Knowledge Graph                          │  │
│   │  - Adjacency lists with property model    │  │
│   │  - Inverted indices on edge types         │  │
│   │  - Full-text search index                 │  │
│   │  - Backed by SQLite for persistence       │  │
│   ├──────────────────────────────────────────┤  │
│   │  Text Substrate                           │  │
│   │  - SumTree rope (Zed pattern)             │  │
│   │  - Tree-sitter incremental parsing        │  │
│   │  - Anchor system for stable positions     │  │
│   │  - CRDT layer (Loro) for future sync      │  │
│   ├──────────────────────────────────────────┤  │
│   │  Incremental Engine (Salsa-inspired)      │  │
│   │  - Tracked queries for derived state      │  │
│   │  - Early cutoff optimization              │  │
│   │  - Change detection feeds render          │  │
│   ├──────────────────────────────────────────┤  │
│   │  Agent Harness                            │  │
│   │  - LLM router (local MLX + API)          │  │
│   │  - MCP host with Rust client             │  │
│   │  - Tool registry (native + subprocess)    │  │
│   │  - Event-sourced action ledger           │  │
│   │  - Graph-aware context builder           │  │
│   └──────────────────────────────────────────┘  │
├─────────────────────────────────────────────────┤
│   Metal Render Substrate                         │
│   ├── Scene builder (flat display list)          │
│   ├── Primitive shaders (quad, glyph, path,      │
│   │   shadow, image) via instanced draw calls    │
│   ├── Glyph atlas (CoreText → Metal texture)     │
│   ├── Graph compute (Barnes-Hut force layout)    │
│   ├── Triple-buffered with CVDisplayLink         │
│   └── Shared MTLBuffer for CPU/GPU data          │
└─────────────────────────────────────────────────┘
```

### The ownership law

Rust owns all canonical state. Swift holds handles (u64 generational indices). Metal receives render commands through shared buffers. Python, if present at all, runs in a separate process and communicates via MCP/JSON-RPC. No exceptions.

### The rendering law

One render pipeline serves all surfaces. Notes, graphs, settings, chat, sidebar—all are projections rendered through the same Metal primitive set. Surface-specific rendering logic (force-directed layout for graphs, text flow for notes, list layout for settings) lives in Rust-side systems that produce surface-specific display lists, but the display lists all consist of the same primitive types submitted to the same Metal shaders.

### The event law

Every mutation flows through the command system. Commands are validated, produce events, events update state, observers fire, views invalidate. The event log enables undo/redo, agent action audit, and future collaboration. No mutation bypasses this path—not user input, not agent actions, not sync operations.

---

## 11. Migration roadmap

### Phase 0: Audit (days 1–30)

**Week 1–2**: Map every distinct state store in the app. For each, document: what data it holds, which surfaces read it, which surfaces write it, how changes propagate, whether it persists. Tag each store as canonical or session. Identify every place where the same logical data exists in two stores with different representations.

**Week 3**: Map every FFI boundary. Measure UniFFI call overhead for the 20 most frequent cross-boundary calls using Instruments. Identify hot paths (>100 calls/sec), warm paths (1–100), cold paths (<1). Measure total bridging code size with `nm` and link map analysis.

**Week 4**: Map every rendering subsystem. Count distinct rendering technologies (SwiftUI views, AppKit custom views, Metal views, Core Animation layers). Document which surfaces use which renderers. Measure frame times per surface with Metal System Trace. Identify the most expensive rendering paths.

**Deliverable**: A dependency graph showing every state store, every FFI boundary, and every rendering subsystem, annotated with measured costs.

### Phase 1: Substrate foundation (days 31–75)

**Extract the entity store.** Build the Rust-side entity store with generational handles, the lease pattern, and the effect queue. Start with the knowledge graph: notes, links, tags. Expose entity handles to Swift via a thin C ABI (`entity_create`, `entity_get_component`, `entity_update`). Keep all existing Swift UI code; replace only the underlying data access path.

**Unify identity.** Assign every note a single entity ID. Replace all per-surface IDs (sidebar index, graph node ID, editor document ID) with the canonical entity ID. This is the highest-leverage change: once identity is unified, observation and rendering follow naturally.

**Introduce the command system.** Define the command enum in Rust: `CreateNote`, `UpdateContent`, `LinkNotes`, `ChangeTag`, `DeleteNote`. Route all mutations through commands. Implement the event log. Wire undo/redo to history index manipulation.

### Phase 2: Rendering unification (days 76–120)

**Build the Metal render substrate.** Implement primitive-specific shaders for quads, glyphs, paths, and shadows. Build the glyph atlas with CoreText shaping. Implement the display list builder.

**Migrate the graph view first** (most isolated, most Metal-appropriate). Replace the existing graph rendering with the unified Metal pipeline. Implement Barnes-Hut force layout in Metal compute shaders.

**Migrate the text editor second.** Build the SumTree rope, integrate Tree-sitter for Markdown parsing, implement the six-layer display pipeline (inlay → fold → tab → wrap → block → display). Replace TextKit/SwiftUI text with the custom Metal text renderer.

### Phase 3: Surface migration (days 121–180)

Migrate remaining surfaces (sidebar, settings, chat, landing) to read from the unified entity store and render through the unified pipeline. Keep SwiftUI as the surface description language where it works well (settings panels, simple lists) but render through Metal where performance matters.

### Phase 4: Agent substrate (days 181–240)

Build the agent harness in Rust. Implement MCP host. Integrate local LLM via MLX. Wire the action ledger to the event log. Build the graph-aware context builder. Implement the agent UI event stream.

### Rollback strategy

Each phase is independently deployable behind feature flags. The entity store can coexist with legacy state stores via a sync bridge (entity changes propagate to legacy stores and vice versa). The Metal renderer can coexist with SwiftUI surfaces in different windows. If a phase fails, revert the feature flag without affecting other phases.

### Risk map

**Highest risk**: Text editor migration (Phase 2). Custom text rendering with correct Unicode handling, IME support, selection, and accessibility is 6+ months of focused work. Mitigation: use CoreText for shaping (proven), delegate IME to native NSTextInputClient overlay.

**Medium risk**: Entity store extraction (Phase 1). Requires touching every data access path. Mitigation: introduce the entity store alongside existing stores with a sync bridge; migrate access paths incrementally.

**Lowest risk**: Agent substrate (Phase 4). Independent of other phases. Can proceed in parallel once the entity store exists.

---

## 12. Risk map and anti-patterns

### Anti-pattern: the serialization sandwich

Sending data from Rust → serialize to JSON/protobuf → deserialize in Swift → process → serialize back → deserialize in Rust. Xi-editor died from this. Every boundary crossing should be a pointer or handle, not a serialization round-trip. If you must serialize, do it once (FlatBuffers) and read zero-copy thereafter.

### Anti-pattern: the double-synchronization trap

Swift actor isolation + Rust mutex on the same logical lock. When a `@MainActor`-isolated Swift function calls a UniFFI-generated bridge that acquires a Rust `Mutex`, and the Rust side tries to call back into Swift (which requires scheduling on the main actor), deadlock occurs. **Rule**: never hold a Rust lock while crossing back to Swift. Use the effect queue pattern instead—push effects, flush later.

### Anti-pattern: SwiftUI as primary architecture

SwiftUI is a rendering technology, not an application architecture. Its performance cliffs are real (Grila's 365-view year view, Fatbobman's `@State` sharing bug). Its navigation system has been rewritten three times across WWDC sessions. It cannot handle hundreds of interactive elements at 60fps for canvases or graphs. **Use SwiftUI for what it's good at**: declarative description of standard UI controls. Don't make it the architectural spine.

### Anti-pattern: premature ECS

Full ECS migration is extremely high risk for a 250K-line app with an existing team. The paradigm shift is significant. **Adopt the useful patterns** (entity-handle identity, component-like state decomposition, system-like query patterns) without requiring a full ECS framework. GPUI proves you can get 90% of the architectural benefit with a simpler entity store.

### Anti-pattern: embedded Python for core functionality

Every line of Python embedded in the main process is a line that can crash the app, block the GIL, bloat the binary, and resist sandboxing. Use subprocess isolation for all Python. Reserve native Rust/Swift for everything performance-sensitive or safety-critical.

---

## 13. Concrete audit checklist

**State stores** (for each): What data? Which surfaces read? Which write? How do changes propagate? Canonical or session? Duplicated elsewhere?

**FFI boundaries** (for each): Call frequency (measured)? Data size per call? Copying or referencing? String materialization? Can it be eliminated, batched, or moved to C ABI?

**Rendering paths** (for each surface): Technology (SwiftUI/AppKit/Metal/Core Animation)? Frame time (measured)? View count? Invalidation strategy? Could it use the unified Metal pipeline?

**Binary size** (by component): Run `cargo bloat --release --crates` on Rust side. Generate link map on Swift side. Measure: UniFFI scaffolding size, unused framework imports, bundled asset sizes, shader archive size.

**Memory** (per surface): RSS at idle, RSS at full load, allocations per frame. Identify: leaked observers, retained closures, uncollected entity handles, SwiftUI view identity thrash.

**Launch time**: Measure pre-main (dyld loading) and post-main (initialization) separately. `DYLD_PRINT_STATISTICS=1`. Target: <200ms to first frame.

---

## 14. Final verdict

**Should the app keep modularity?** Yes, but the right kind. Surfaces must be modular—a graph view, a notes editor, a settings panel, and a chat interface have genuinely different rendering and interaction needs. **The core must not be modular.** Identity, state ownership, the command grammar, the event log, and the render primitive set must be unified and singular. Modularity at the surface level, singularity at the substrate level.

**What must be unified at all costs?** Entity identity (one ID per entity, everywhere). State ownership (Rust owns canonical, Swift projects). The command/event system (one path for all mutations). The render primitive set (one set of Metal shaders for all surfaces).

**Correct meaning of singularity?** Not "one giant module" but "one source of truth." The entity store is the single source of truth for what exists. The event log is the single source of truth for what happened. The render substrate is the single source of truth for how things look. Surfaces are many. Truth is one.

**Realistic path toward compactness?** Unified render substrate (-2–5 MB from eliminating duplicate subsystems). Custom C ABI for hot paths (-0.5–1 MB from UniFFI scaffolding). Rust profile optimization (strip, LTO, -Oz, panic=abort: -60% from default). Swift stripping and reflection removal (-25–30%). Remove embedded Python (-15–25 MB). **Target: 10–15 MB without Python.**

**Best substrate architecture?** Option A: Rust-owned entity graph with Swift projection shells. Incorporates the entity-handle pattern from GPUI, the effect queue for reentrancy safety, the command/event system from event-sourcing, Salsa-inspired incremental computation for derived state, and the Metal render substrate with primitive-specific shaders.

**Best FFI strategy?** Tiered: custom C ABI for rendering, input, and entity queries; swift-bridge for typed warm-path calls; UniFFI for configuration and cold-path operations. String interning via u32 symbol IDs. Arena-scoped borrowed spans for batch data. Ring buffers for event streaming.

**Where should Python live?** In a subprocess, communicating via MCP over stdio. Not embedded. JavaScriptCore for user scripting. This is the single highest-leverage decision for binary size and runtime simplicity.

**Best agentic harness architecture?** Rust-native agent loop. MCP host with Rust client for tool integration. MCP server exposing the knowledge graph to external AI tools. Graph-aware context construction via native graph traversal. Event-sourced action ledger feeding a typed UI event stream. Local MLX inference with API escalation. Permission tiers with progressive trust.

The substrate is not a framework to adopt. It is a law to discover—the law that was already implicit in the app's aspirations, waiting to be made explicit in its architecture.