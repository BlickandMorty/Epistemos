# Embedded Graph Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an embedded graph view to the Notes workspace — as a standalone tab and a pinnable right-side split — reusing the Metal + Rust FFI rendering pipeline.

**Architecture:** New `EmbeddedGraphState` (@Observable) owns a separate Rust engine handle. New `EmbeddedGraphNSView` (NSView subclass) renders via Metal, following the same patterns as `MetalGraphNSView` but reading from `EmbeddedGraphState` instead of `GraphState`. Workspace routing in `NotesWorkspaceView` conditionally renders graph tab, split view, or normal editor based on state. Shared `GraphStore` provides data — no duplication.

**Tech Stack:** Swift, SwiftUI, AppKit (NSView/NSViewRepresentable), Metal, Rust FFI (`graph-engine`)

**Spec:** `docs/plans/2026-03-10-embedded-graph-design.md`

---

## File Map

### New Files

| File | Responsibility |
|------|---------------|
| `Epistemos/State/EmbeddedGraphState.swift` | @Observable state: visibility, split, scope, engine handle, hover, splitRatio |
| `Epistemos/State/GraphNavigationState.swift` | Navigation stack with graph-as-root, wraps optional NoteNavigationState for note drill-in |
| `Epistemos/Views/Notes/EmbeddedGraphNSView.swift` | NSView subclass: CAMetalLayer + own GraphEngine, 30Hz display link, mouse events, context menu |
| `Epistemos/Views/Notes/EmbeddedGraphView.swift` | NSViewRepresentable wrapping EmbeddedGraphNSView for SwiftUI |
| `Epistemos/Views/Notes/GraphNodePopover.swift` | SwiftUI popover: title, connections, "Open Note" / "Focus" buttons |
| `Epistemos/Views/Notes/GraphSplitView.swift` | Resizable HSplitView: editor left, graph right, draggable divider |

### Modified Files

| File | Change |
|------|--------|
| `Epistemos/State/NotesUIState.swift` | Add `isGraphTab` to `WorkspaceTab`, add `openGraphTab()`, update `resetForVaultSwitch()` |
| `Epistemos/Views/Notes/NotesWorkspaceView.swift` | Detail pane routing: graph tab, split mode, landing button replacement (landing view is inline ~line 195) |
| `Epistemos/App/AppBootstrap.swift` | Create `EmbeddedGraphState` instance, add vault switch reset |
| `Epistemos/App/AppEnvironment.swift` | Add `.environment(bootstrap.embeddedGraphState)` |

---

## Chunk 1: State Layer

### Task 1: EmbeddedGraphState

**Files:**
- Create: `Epistemos/State/EmbeddedGraphState.swift`
- Test: `EpistemosTests/EmbeddedGraphStateTests.swift`

- [ ] **Step 1: Write failing tests for EmbeddedGraphState**

```swift
// EpistemosTests/EmbeddedGraphStateTests.swift
import Testing
@testable import Epistemos

@Suite("EmbeddedGraphState")
struct EmbeddedGraphStateTests {

    @Test @MainActor func defaultState() {
        let state = EmbeddedGraphState()
        #expect(state.isVisible == false)
        #expect(state.isSplitActive == false)
        #expect(state.scope == .global)
        #expect(state.focusedNodeId == nil)
        #expect(state.hoveredNodeId == nil)
        #expect(state.splitRatio == 0.55)
        #expect(state.engineHandle == nil)
    }

    @Test @MainActor func splitRatioClampsLow() {
        let state = EmbeddedGraphState()
        state.splitRatio = 0.1
        #expect(state.splitRatio == 0.3)
    }

    @Test @MainActor func splitRatioClampsHigh() {
        let state = EmbeddedGraphState()
        state.splitRatio = 0.95
        #expect(state.splitRatio == 0.8)
    }

    @Test @MainActor func resetForVaultSwitch() {
        let state = EmbeddedGraphState()
        state.isVisible = true
        state.isSplitActive = true
        state.scope = .local(noteId: "abc")
        state.focusedNodeId = "xyz"
        state.hoveredNodeId = "xyz"

        state.resetForVaultSwitch()

        #expect(state.isVisible == false)
        #expect(state.isSplitActive == false)
        #expect(state.scope == .global)
        #expect(state.focusedNodeId == nil)
        #expect(state.hoveredNodeId == nil)
    }

    @Test @MainActor func activateSplitSetsLocalScope() {
        let state = EmbeddedGraphState()
        state.activateSplit(focusingNoteId: "note-1")
        #expect(state.isSplitActive == true)
        #expect(state.scope == .local(noteId: "note-1"))
    }

    @Test @MainActor func deactivateSplitRestoresGlobal() {
        let state = EmbeddedGraphState()
        state.activateSplit(focusingNoteId: "note-1")
        state.deactivateSplit()
        #expect(state.isSplitActive == false)
        #expect(state.scope == .global)
    }

    @Test @MainActor func followNavigationUpdatesScope() {
        let state = EmbeddedGraphState()
        state.isSplitActive = true
        state.scope = .local(noteId: "note-1")

        state.followNavigation(to: "note-2")

        #expect(state.scope == .local(noteId: "note-2"))
        #expect(state.focusedNodeId == "note-2")
    }

    @Test @MainActor func followNavigationNoopWhenGlobal() {
        let state = EmbeddedGraphState()
        state.scope = .global
        state.followNavigation(to: "note-2")
        // Global scope should not change
        #expect(state.scope == .global)
        // But focusedNodeId should still update for highlight
        #expect(state.focusedNodeId == "note-2")
    }
}
```

- [ ] **Step 2: Run tests — verify they fail**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test 2>&1 | grep -E 'EmbeddedGraphState|error:'`
Expected: Compilation error — `EmbeddedGraphState` not defined.

- [ ] **Step 3: Implement EmbeddedGraphState**

```swift
// Epistemos/State/EmbeddedGraphState.swift
import Foundation

enum EmbeddedGraphScope: Equatable, Sendable {
    case global
    case local(noteId: String)
}

@MainActor @Observable
final class EmbeddedGraphState {

    var isVisible = false
    var isSplitActive = false
    var scope: EmbeddedGraphScope = .global
    var focusedNodeId: String?
    var hoveredNodeId: String?

    /// Engine handle set by EmbeddedGraphNSView after Metal setup.
    /// Cleared on view teardown or vault switch.
    nonisolated(unsafe) var engineHandle: OpaquePointer?

    /// Fraction of detail pane allocated to editor (left side).
    /// Clamped to 0.3–0.8. Persisted in UserDefaults.
    var splitRatio: CGFloat = 0.55 {
        didSet {
            let clamped = min(0.8, max(0.3, splitRatio))
            if splitRatio != clamped { splitRatio = clamped }
        }
    }

    // MARK: - Actions

    func activateSplit(focusingNoteId noteId: String) {
        isSplitActive = true
        scope = .local(noteId: noteId)
        focusedNodeId = noteId
    }

    func deactivateSplit() {
        isSplitActive = false
        scope = .global
    }

    /// Called when the user navigates to a different note while split is active.
    /// Updates local scope and focused node highlight.
    func followNavigation(to noteId: String) {
        focusedNodeId = noteId
        if case .local = scope {
            scope = .local(noteId: noteId)
        }
    }

    func resetForVaultSwitch() {
        isVisible = false
        isSplitActive = false
        scope = .global
        focusedNodeId = nil
        hoveredNodeId = nil
        // engineHandle is cleared by the NSView's deinit — don't destroy here.
        // The view will be removed as part of workspace tab reset.
    }
}
```

- [ ] **Step 4: Run tests — verify they pass**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test 2>&1 | grep -E 'EmbeddedGraphState|Test Suite|passed|failed'`
Expected: All 8 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Epistemos/State/EmbeddedGraphState.swift EpistemosTests/EmbeddedGraphStateTests.swift
git commit -m "feat: add EmbeddedGraphState with split/scope/navigation"
```

---

### Task 2: GraphNavigationState

**Files:**
- Create: `Epistemos/State/GraphNavigationState.swift`
- Test: `EpistemosTests/GraphNavigationStateTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// EpistemosTests/GraphNavigationStateTests.swift
import Testing
@testable import Epistemos

@Suite("GraphNavigationState")
struct GraphNavigationStateTests {

    @Test @MainActor func startsAtGraphRoot() {
        let state = GraphNavigationState()
        #expect(state.isAtGraphRoot == true)
        #expect(state.currentPageId == nil)
        #expect(state.canGoBack == false)
    }

    @Test @MainActor func pushNoteFromGraph() {
        let state = GraphNavigationState()
        state.pushNote(pageId: "page-1", title: "My Note")
        #expect(state.isAtGraphRoot == false)
        #expect(state.currentPageId == "page-1")
        #expect(state.canGoBack == true)
    }

    @Test @MainActor func backReturnsToGraph() {
        let state = GraphNavigationState()
        state.pushNote(pageId: "page-1", title: "My Note")
        state.backToGraph()
        #expect(state.isAtGraphRoot == true)
        #expect(state.currentPageId == nil)
    }

    @Test @MainActor func wikiLinkNavigationWithinNote() {
        let state = GraphNavigationState()
        state.pushNote(pageId: "page-1", title: "Note 1")
        state.pushNote(pageId: "page-2", title: "Note 2")
        #expect(state.currentPageId == "page-2")
        #expect(state.canGoBack == true)
    }

    @Test @MainActor func backThroughNoteStackToGraph() {
        let state = GraphNavigationState()
        state.pushNote(pageId: "page-1", title: "Note 1")
        state.pushNote(pageId: "page-2", title: "Note 2")
        state.back()
        #expect(state.currentPageId == "page-1")
        state.back()
        #expect(state.isAtGraphRoot == true)
    }

    @Test @MainActor func resetClearsStack() {
        let state = GraphNavigationState()
        state.pushNote(pageId: "p1", title: "t1")
        state.pushNote(pageId: "p2", title: "t2")
        state.reset()
        #expect(state.isAtGraphRoot == true)
        #expect(state.canGoBack == false)
    }
}
```

- [ ] **Step 2: Run tests — verify they fail**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test 2>&1 | grep -E 'GraphNavigationState|error:'`
Expected: Compilation error.

- [ ] **Step 3: Implement GraphNavigationState**

```swift
// Epistemos/State/GraphNavigationState.swift
import Foundation

/// Navigation stack for the embedded graph tab.
/// Graph is the root (no page ID). Notes are pushed on top.
@MainActor @Observable
final class GraphNavigationState {

    struct BreadcrumbItem: Equatable {
        let pageId: String
        let title: String
    }

    private(set) var noteStack: [BreadcrumbItem] = []

    var isAtGraphRoot: Bool { noteStack.isEmpty }

    var currentPageId: String? { noteStack.last?.pageId }

    var canGoBack: Bool { !noteStack.isEmpty }

    func pushNote(pageId: String, title: String) {
        noteStack.append(BreadcrumbItem(pageId: pageId, title: title))
    }

    /// Pop one level. If at first note, returns to graph root.
    func back() {
        guard !noteStack.isEmpty else { return }
        noteStack.removeLast()
    }

    /// Jump straight back to graph root.
    func backToGraph() {
        noteStack.removeAll()
    }

    func reset() {
        noteStack.removeAll()
    }
}
```

- [ ] **Step 4: Run tests — verify they pass**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test 2>&1 | grep -E 'GraphNavigationState|passed|failed'`
Expected: All 6 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Epistemos/State/GraphNavigationState.swift EpistemosTests/GraphNavigationStateTests.swift
git commit -m "feat: add GraphNavigationState with graph-as-root nav stack"
```

---

### Task 3: Wire State into NotesUIState + AppEnvironment

**Files:**
- Modify: `Epistemos/State/NotesUIState.swift` (lines 10-20 WorkspaceTab, line 215 resetForVaultSwitch)
- Modify: `Epistemos/App/AppBootstrap.swift` (line ~34)
- Modify: `Epistemos/App/AppEnvironment.swift` (line ~32)

- [ ] **Step 1: Write failing test for WorkspaceTab.isGraphTab**

Add to existing test file or create `EpistemosTests/NotesUIStateGraphTests.swift`:

```swift
// EpistemosTests/NotesUIStateGraphTests.swift
import Testing
@testable import Epistemos

@Suite("NotesUIState Graph Integration")
struct NotesUIStateGraphTests {

    @Test @MainActor func workspaceTabDefaultsNonGraph() {
        let tab = NotesUIState.WorkspaceTab()
        #expect(tab.isGraphTab == false)
    }

    @Test @MainActor func openGraphTabCreatesGraphTab() {
        let state = NotesUIState()
        let tabId = state.openGraphTab()
        let tab = state.workspaceTabs.first(where: { $0.id == tabId })
        #expect(tab != nil)
        #expect(tab?.isGraphTab == true)
        #expect(tab?.pageId == nil)
        #expect(state.workspaceActiveTabId == tabId)
    }

    @Test @MainActor func openGraphTabReusesExisting() {
        let state = NotesUIState()
        let first = state.openGraphTab()
        let second = state.openGraphTab()
        #expect(first == second)
        #expect(state.workspaceTabs.filter(\.isGraphTab).count == 1)
    }

    @Test @MainActor func resetForVaultSwitchClearsGraphTab() {
        let state = NotesUIState()
        _ = state.openGraphTab()
        state.resetForVaultSwitch()
        #expect(state.workspaceTabs.filter(\.isGraphTab).isEmpty)
    }
}
```

- [ ] **Step 2: Run tests — verify they fail**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test 2>&1 | grep -E 'NotesUIStateGraph|error:'`
Expected: Compilation error — `isGraphTab` not found on `WorkspaceTab`.

- [ ] **Step 3: Add isGraphTab to WorkspaceTab**

In `Epistemos/State/NotesUIState.swift`, modify the `WorkspaceTab` struct (lines 10-20):

Add `var isGraphTab: Bool` property with default `false` to the struct and init:

```swift
struct WorkspaceTab: Identifiable, Equatable {
    let id: String
    var pageId: String?
    var isPinned: Bool
    var isGraphTab: Bool

    init(id: String = UUID().uuidString, pageId: String? = nil, isPinned: Bool = false, isGraphTab: Bool = false) {
        self.id = id
        self.pageId = pageId
        self.isPinned = isPinned
        self.isGraphTab = isGraphTab
    }
}
```

- [ ] **Step 4: Add openGraphTab() method**

In `NotesUIState`, add after `openWorkspacePage` (around line 137):

```swift
/// Opens the embedded graph as a workspace tab. Reuses existing graph tab if one exists.
/// Returns the tab ID.
@discardableResult
func openGraphTab() -> String {
    if let existing = workspaceTabs.first(where: \.isGraphTab) {
        workspaceActiveTabId = existing.id
        return existing.id
    }
    let tab = WorkspaceTab(isGraphTab: true)
    workspaceTabs.append(tab)
    workspaceActiveTabId = tab.id
    return tab.id
}
```

- [ ] **Step 5: Update resetForVaultSwitch()**

In `NotesUIState.resetForVaultSwitch()` (line ~215), the existing code already resets `workspaceTabs` to a single landing tab — which inherently clears any graph tab. No change needed here since `WorkspaceTab()` defaults to `isGraphTab: false`. But add a comment for clarity:

After `workspaceTabs = [landingTab]`, no additional change needed — the new landing tab has `isGraphTab: false` by default.

- [ ] **Step 6: Add EmbeddedGraphState to AppBootstrap**

In `Epistemos/App/AppBootstrap.swift`, add after `let physicsCoordinator = PhysicsCoordinator()` (~line 36):

```swift
let embeddedGraphState = EmbeddedGraphState()
```

- [ ] **Step 7: Add to AppEnvironment**

In `Epistemos/App/AppEnvironment.swift`, add before the closing of `withAppEnvironment` (before line 32):

```swift
.environment(bootstrap.embeddedGraphState)
```

- [ ] **Step 8: Run all tests**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test 2>&1 | grep -E 'NotesUIStateGraph|EmbeddedGraph|passed|failed|error'`
Expected: All new tests pass, no regressions.

- [ ] **Step 9: Commit**

```bash
git add Epistemos/State/NotesUIState.swift Epistemos/App/AppBootstrap.swift Epistemos/App/AppEnvironment.swift EpistemosTests/NotesUIStateGraphTests.swift
git commit -m "feat: wire EmbeddedGraphState into workspace tabs and app environment"
```

---

## Chunk 2: Metal Rendering Layer

### Task 4: EmbeddedGraphNSView

**Files:**
- Create: `Epistemos/Views/Notes/EmbeddedGraphNSView.swift`

**Context:** This is the core Metal rendering NSView. It follows the same pattern as `MetalGraphNSView` (in `Views/Graph/MetalGraphView.swift`) but reads from `EmbeddedGraphState` and operates at 30Hz. Key reference points:
- `MetalGraphView.swift:171-187` — `setupMetal()` pattern (device, layer, engine creation)
- `MetalGraphView.swift:44-120` — Property declarations, display link setup
- `MetalGraphView.swift:866-1007` — Mouse event handling (mouseDown/Up/Moved, right-click)
- `graph-engine-bridge/graph_engine.h:20-81` — FFI function signatures

- [ ] **Step 1: Create EmbeddedGraphNSView skeleton**

Create `Epistemos/Views/Notes/EmbeddedGraphNSView.swift` with:

```swift
import Cocoa
import MetalKit
import Synchronization

/// Metal-rendered graph view for the embedded workspace graph.
/// Owns its own Rust engine handle, separate from HologramOverlay.
/// Runs at 30Hz (vs 60Hz overlay) to reduce resource usage.
final class EmbeddedGraphNSView: NSView {

    // MARK: - Engine & Rendering

    nonisolated(unsafe) private var engine: OpaquePointer?
    nonisolated(unsafe) private var displayLink: CVDisplayLink?
    private var metalLayer: CAMetalLayer?
    nonisolated(unsafe) private let framePending = Atomic<Bool>(false)
    nonisolated(unsafe) private let renderNeeded = Atomic<Bool>(true)
    nonisolated(unsafe) private let isInvalidated = Atomic<Bool>(false)

    /// Frame counter for 30Hz throttle (render every other frame on 60Hz display).
    nonisolated(unsafe) private var frameCounter: UInt64 = 0

    // MARK: - State References

    /// Set by EmbeddedGraphView (NSViewRepresentable) makeNSView.
    nonisolated(unsafe) var embeddedGraphState: EmbeddedGraphState?

    /// Shared graph data — read-only.
    nonisolated(unsafe) var graphStore: GraphStore?

    // MARK: - Interaction State

    private var mouseDownLocation: CGPoint?
    private var isDraggingNode = false
    private var isPanning = false

    // MARK: - Callbacks

    /// Called when a node is tapped (single click). Receives node UUID.
    var onNodeTap: ((String) -> Void)?

    /// Called when a node is double-clicked. Receives node UUID.
    var onNodeDoubleTap: ((String) -> Void)?

    /// Called on background tap (click without hitting a node).
    var onBackgroundTap: (() -> Void)?

    var needsRender: Bool {
        get { renderNeeded.load(ordering: .relaxed) }
        set { renderNeeded.store(newValue, ordering: .relaxed) }
    }

    // MARK: - Lifecycle

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer = CAMetalLayer()
        setupMetal()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    deinit {
        isInvalidated.store(true, ordering: .release)
        stopDisplayLink()
        if let engine {
            graph_engine_destroy(engine)
        }
        Task { @MainActor [weak state = embeddedGraphState] in
            state?.engineHandle = nil
        }
    }

    // MARK: - Metal Setup

    private func setupMetal() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let layer = self.layer as? CAMetalLayer else { return }
        layer.device = device
        layer.pixelFormat = .bgra8Unorm
        layer.framebufferOnly = true
        metalLayer = layer

        let devicePtr = Unmanaged.passUnretained(device).toOpaque()
        let layerPtr = Unmanaged.passUnretained(layer).toOpaque()
        engine = graph_engine_create(devicePtr, layerPtr)

        // Enable lite mode (lighter rendering than overlay — no 3D effects)
        graph_engine_set_lite_mode(engine!, 1)

        // Opaque background (not overlay-transparent)
        graph_engine_set_clear_color(engine!, 0.08, 0.08, 0.10, 1.0)

        // Sync with system appearance
        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        graph_engine_set_light_mode(engine!, isDark ? 0 : 1)

        Task { @MainActor [weak self] in
            self?.embeddedGraphState?.engineHandle = self?.engine
        }

        startDisplayLink()
    }

    // MARK: - Display Link (30Hz)

    private func startDisplayLink() {
        guard displayLink == nil else { return }
        var dl: CVDisplayLink?
        CVDisplayLinkCreateWithActiveCGDisplays(&dl)
        guard let dl else { return }
        displayLink = dl

        let framePending = self.framePending
        let isInvalidated = self.isInvalidated
        var counter: UInt64 = 0

        // CVDisplayLink fires on a background thread.
        // We coalesce frames with `framePending` and dispatch to main for rendering.
        // The Rust engine is NOT thread-safe — all calls must happen on main.
        CVDisplayLinkSetOutputHandler(dl) { [weak self] _, _, _, _, _ -> CVReturn in
            guard !isInvalidated.load(ordering: .acquire) else { return kCVReturnSuccess }
            // 30Hz: skip every other frame on 60Hz display
            counter += 1
            guard counter % 2 == 0 else { return kCVReturnSuccess }

            guard !framePending.load(ordering: .relaxed) else { return kCVReturnSuccess }
            framePending.store(true, ordering: .relaxed)

            Task { @MainActor [weak self] in
                self?.renderFrame()
            }
            return kCVReturnSuccess
        }
        CVDisplayLinkStart(dl)
    }

    /// Called on the main thread by the display link dispatch.
    /// Mirrors MetalGraphNSView.renderFrame() pattern.
    @MainActor private func renderFrame() {
        defer { framePending.store(false, ordering: .relaxed) }
        guard !isInvalidated.load(ordering: .acquire),
              let engine,
              let layer = metalLayer else { return }

        let size = layer.drawableSize
        let w = UInt32(size.width)
        let h = UInt32(size.height)
        guard w > 0, h > 0 else { return }

        // graph_engine_render(engine, uint32_t width, uint32_t height) → uint32_t
        // Returns 1 if more frames needed, 0 if settled
        let needsMore = graph_engine_render(engine, w, h)
        if needsMore == 0 {
            // Physics settled — stop requesting frames until next interaction
            renderNeeded.store(false, ordering: .relaxed)
        }
    }

    private func stopDisplayLink() {
        guard let dl = displayLink else { return }
        CVDisplayLinkStop(dl)
        displayLink = nil
    }

    // MARK: - Data Loading

    /// Full sync: clear engine, batch-load all nodes/edges from GraphStore, commit.
    /// Uses batch FFI (graph_engine_add_nodes_batch / add_edges_batch) for O(1) boundary crossings.
    func syncFullGraph() {
        guard let engine, let store = graphStore else { return }
        graph_engine_clear(engine)

        commitNodes(Array(store.nodes.values), store: store)
        commitEdges(Array(store.edges.values), store: store)

        graph_engine_commit(engine, 1) // 1 = spiral entrance layout
        needsRender = true
    }

    /// Load local subgraph: only nodes within `depth` hops of `centerNodeId`.
    func syncLocalGraph(centerNodeId: String, depth: Int = 2) {
        guard let engine, let store = graphStore else { return }
        graph_engine_clear(engine)

        // BFS to find local neighborhood
        var visited = Set<String>()
        var queue: [(String, Int)] = [(centerNodeId, 0)]
        visited.insert(centerNodeId)

        while let (nodeId, d) = queue.first {
            queue.removeFirst()
            if let neighbors = store.adjacency[nodeId], d < depth {
                for neighbor in neighbors where !visited.contains(neighbor) {
                    visited.insert(neighbor)
                    queue.append((neighbor, d + 1))
                }
            }
        }

        let nodes = visited.compactMap { store.nodes[$0] }
        commitNodes(nodes, store: store)

        let edges = store.edges.values.filter {
            visited.contains($0.sourceNodeId) && visited.contains($0.targetNodeId)
        }
        commitEdges(Array(edges), store: store)

        graph_engine_commit(engine, 1)

        // Center on the focus node
        centerNodeId.withCString { uuid in
            graph_engine_center_on_node(engine, uuid)
        }
        needsRender = true
    }

    // MARK: - Batch FFI Helpers

    /// Batch-add nodes to the Rust engine. Uses graph_engine_add_nodes_batch.
    private func commitNodes(_ nodes: [GraphNodeRecord], store: GraphStore) {
        guard let engine, !nodes.isEmpty else { return }

        var nodeIds = nodes.map(\.id)
        var nodeXs = nodes.map(\.position.x)
        var nodeYs = nodes.map(\.position.y)
        var nodeTypes: [UInt8] = nodes.map(\.type.rustIndex)
        var nodeLinkCounts: [UInt32] = nodes.map { store.linkCount(for: $0.id) }
        var nodeLabels = nodes.map(\.label)

        let uuidCPtrs = nodeIds.map { $0.utf8CString }
        let labelCPtrs = nodeLabels.map { $0.utf8CString }
        var uuidPtrs: [UnsafePointer<CChar>?] = uuidCPtrs.map { UnsafePointer($0) }
        var labelPtrs: [UnsafePointer<CChar>?] = labelCPtrs.map { UnsafePointer($0) }

        uuidPtrs.withUnsafeMutableBufferPointer { uPtrs in
            labelPtrs.withUnsafeMutableBufferPointer { lPtrs in
                nodeXs.withUnsafeBufferPointer { xs in
                    nodeYs.withUnsafeBufferPointer { ys in
                        nodeTypes.withUnsafeBufferPointer { types in
                            nodeLinkCounts.withUnsafeBufferPointer { links in
                                graph_engine_add_nodes_batch(
                                    engine,
                                    uPtrs.baseAddress,
                                    xs.baseAddress,
                                    ys.baseAddress,
                                    types.baseAddress,
                                    links.baseAddress,
                                    lPtrs.baseAddress,
                                    UInt32(nodes.count)
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    /// Batch-add edges to the Rust engine. Uses graph_engine_add_edges_batch.
    private func commitEdges(_ edges: [GraphEdgeRecord], store: GraphStore) {
        guard let engine, !edges.isEmpty else { return }

        var edgeSrcs = edges.map(\.sourceNodeId)
        var edgeTgts = edges.map(\.targetNodeId)
        var edgeWeights: [Float] = edges.map { Float($0.weight) }
        var edgeTypes: [UInt8] = edges.map(\.type.rustIndex)

        let srcCPtrs = edgeSrcs.map { $0.utf8CString }
        let tgtCPtrs = edgeTgts.map { $0.utf8CString }
        var srcPtrs: [UnsafePointer<CChar>?] = srcCPtrs.map { UnsafePointer($0) }
        var tgtPtrs: [UnsafePointer<CChar>?] = tgtCPtrs.map { UnsafePointer($0) }

        srcPtrs.withUnsafeMutableBufferPointer { sPtrs in
            tgtPtrs.withUnsafeMutableBufferPointer { tPtrs in
                edgeWeights.withUnsafeBufferPointer { wts in
                    edgeTypes.withUnsafeBufferPointer { types in
                        graph_engine_add_edges_batch(
                            engine,
                            sPtrs.baseAddress,
                            tPtrs.baseAddress,
                            wts.baseAddress,
                            types.baseAddress,
                            UInt32(edges.count)
                        )
                    }
                }
            }
        }
    }

    // MARK: - Layout

    override func layout() {
        super.layout()
        guard let layer = metalLayer else { return }
        let scale = window?.backingScaleFactor ?? 2.0
        layer.contentsScale = scale
        layer.drawableSize = CGSize(width: bounds.width * scale, height: bounds.height * scale)
        // No graph_engine_resize — renderFrame() passes current size to graph_engine_render(engine, w, h)
        needsRender = true
    }

    // MARK: - Mouse Events

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        if window?.firstResponder !== self { window?.makeFirstResponder(self) }
        guard let engine else { return }
        let loc = convert(event.locationInWindow, from: nil)
        mouseDownLocation = loc
        let scale = metalLayer?.contentsScale ?? 2.0
        graph_engine_mouse_down(engine, Float(loc.x * scale), Float((bounds.height - loc.y) * scale), 0)
        needsRender = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let engine else { return }
        let loc = convert(event.locationInWindow, from: nil)
        let scale = metalLayer?.contentsScale ?? 2.0
        graph_engine_mouse_moved(engine, Float(loc.x * scale), Float((bounds.height - loc.y) * scale))
        needsRender = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let engine else { return }
        graph_engine_mouse_up(engine)

        // Detect click vs drag
        if let down = mouseDownLocation {
            let up = convert(event.locationInWindow, from: nil)
            let dx = up.x - down.x, dy = up.y - down.y
            let isClick = dx * dx + dy * dy < 25 // 5px threshold

            if isClick {
                if event.clickCount >= 2 {
                    // Double-click: open note
                    if let uuidPtr = graph_engine_hovered_node_uuid(engine) {
                        let nodeId = String(cString: uuidPtr)
                        onNodeDoubleTap?(nodeId)
                    }
                } else {
                    // Single-click: select node or background tap
                    if let uuidPtr = graph_engine_hovered_node_uuid(engine) {
                        let nodeId = String(cString: uuidPtr)
                        onNodeTap?(nodeId)

                        Task { @MainActor [weak self] in
                            self?.embeddedGraphState?.focusedNodeId = nodeId
                        }
                    } else {
                        onBackgroundTap?()
                        Task { @MainActor [weak self] in
                            self?.embeddedGraphState?.focusedNodeId = nil
                        }
                    }
                }
            }
        }

        mouseDownLocation = nil
        needsRender = true
    }

    override func mouseMoved(with event: NSEvent) {
        guard let engine else { return }
        let loc = convert(event.locationInWindow, from: nil)
        let scale = metalLayer?.contentsScale ?? 2.0
        graph_engine_mouse_moved(engine, Float(loc.x * scale), Float((bounds.height - loc.y) * scale))

        // Update hover state
        if let uuidPtr = graph_engine_hovered_node_uuid(engine) {
            let nodeId = String(cString: uuidPtr)
            Task { @MainActor [weak self] in
                self?.embeddedGraphState?.hoveredNodeId = nodeId
            }
        } else {
            Task { @MainActor [weak self] in
                self?.embeddedGraphState?.hoveredNodeId = nil
            }
        }

        needsRender = true
    }

    override func scrollWheel(with event: NSEvent) {
        guard let engine else { return }
        let loc = convert(event.locationInWindow, from: nil)
        let scale = metalLayer?.contentsScale ?? 2.0
        let sx = Float(loc.x * scale)
        let sy = Float((bounds.height - loc.y) * scale)

        if event.modifierFlags.contains(.option) {
            // Option+scroll = pan (graph_engine_scroll takes delta_x, delta_y only)
            graph_engine_scroll(engine, Float(event.scrollingDeltaX), Float(event.scrollingDeltaY))
        } else {
            // Default scroll = zoom (via graph_engine_magnify)
            let zoomDelta = Float(event.scrollingDeltaY) * 0.01
            graph_engine_magnify(engine, sx, sy, zoomDelta)
        }
        needsRender = true
    }

    override func magnify(with event: NSEvent) {
        guard let engine else { return }
        let loc = convert(event.locationInWindow, from: nil)
        let scale = metalLayer?.contentsScale ?? 2.0
        graph_engine_magnify(engine, Float(loc.x * scale),
                             Float((bounds.height - loc.y) * scale),
                             Float(event.magnification))
        needsRender = true
    }

    // MARK: - Right-Click Context Menu

    override func rightMouseUp(with event: NSEvent) {
        guard let engine else { return }
        let loc = convert(event.locationInWindow, from: nil)
        let scale = metalLayer?.contentsScale ?? 2.0
        graph_engine_mouse_moved(engine, Float(loc.x * scale), Float((bounds.height - loc.y) * scale))

        guard let uuidPtr = graph_engine_hovered_node_uuid(engine) else { return }
        let nodeId = String(cString: uuidPtr)

        let menu = NSMenu()
        let openItem = NSMenuItem(title: "Open Note", action: #selector(contextOpenNote(_:)), keyEquivalent: "")
        openItem.representedObject = nodeId
        menu.addItem(openItem)

        let focusItem = NSMenuItem(title: "Focus on Node", action: #selector(contextFocusNode(_:)), keyEquivalent: "")
        focusItem.representedObject = nodeId
        menu.addItem(focusItem)

        let connectionsItem = NSMenuItem(title: "Show Connections", action: #selector(contextShowConnections(_:)), keyEquivalent: "")
        connectionsItem.representedObject = nodeId
        menu.addItem(connectionsItem)

        menu.addItem(NSMenuItem.separator())

        let copyItem = NSMenuItem(title: "Copy Link", action: #selector(contextCopyLink(_:)), keyEquivalent: "")
        copyItem.representedObject = nodeId
        menu.addItem(copyItem)

        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    @objc private func contextOpenNote(_ sender: NSMenuItem) {
        guard let nodeId = sender.representedObject as? String else { return }
        onNodeDoubleTap?(nodeId)
    }

    @objc private func contextFocusNode(_ sender: NSMenuItem) {
        guard let nodeId = sender.representedObject as? String else { return }
        Task { @MainActor [weak self] in
            self?.embeddedGraphState?.focusedNodeId = nodeId
        }
        if let engine {
            nodeId.withCString { uuid in
                graph_engine_center_on_node(engine, uuid)
            }
        }
        needsRender = true
    }

    @objc private func contextShowConnections(_ sender: NSMenuItem) {
        guard let nodeId = sender.representedObject as? String else { return }
        if let engine {
            nodeId.withCString { uuid in
                graph_engine_highlight_neighbors(engine, uuid)
            }
        }
        needsRender = true
    }

    @objc private func contextCopyLink(_ sender: NSMenuItem) {
        guard let nodeId = sender.representedObject as? String else { return }
        guard let store = graphStore, let node = store.nodes[nodeId] else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("[[\(node.label)]]", forType: .string)
    }

    // MARK: - Pause / Resume

    /// Pause physics when graph tab is not visible (saves CPU).
    func pauseEngine() {
        guard let engine else { return }
        graph_engine_pause(engine)
    }

    /// Resume physics when graph tab becomes visible again.
    func resumeEngine() {
        guard let engine else { return }
        graph_engine_resume(engine)
        needsRender = true
    }

    // MARK: - Tracking Areas

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
    }
}
```

**FFI functions used (all verified against `graph-engine-bridge/graph_engine.h`):**
`graph_engine_create`, `graph_engine_destroy`, `graph_engine_clear`, `graph_engine_add_nodes_batch(engine, uuids, xs, ys, node_types, link_counts, labels, count)`, `graph_engine_add_edges_batch(engine, source_uuids, target_uuids, weights, edge_types, count)`, `graph_engine_commit(engine, entrance)`, `graph_engine_render(engine, uint32_t width, uint32_t height) → uint32_t`, `graph_engine_mouse_down(engine, screen_x, screen_y, shift)`, `graph_engine_mouse_up(engine)`, `graph_engine_mouse_moved(engine, screen_x, screen_y)`, `graph_engine_scroll(engine, delta_x, delta_y)`, `graph_engine_magnify(engine, screen_x, screen_y, magnification)`, `graph_engine_hovered_node_uuid(engine) → const char*`, `graph_engine_center_on_node(engine, uuid)`, `graph_engine_highlight_neighbors(engine, uuid)`, `graph_engine_node_screen_pos(engine, uuid, out_xy) → uint8_t`, `graph_engine_pause(engine)`, `graph_engine_resume(engine)`, `graph_engine_set_lite_mode(engine, enabled)`, `graph_engine_set_clear_color(engine, r, g, b, a)`, `graph_engine_set_light_mode(engine, enabled)`.

**Functions that do NOT exist** (common mistakes): ~~`graph_engine_tick`~~, ~~`graph_engine_resize`~~, ~~`graph_engine_pinch`~~, ~~`graph_engine_focus_node`~~. See above code for correct replacements.

- [ ] **Step 2: Verify it compiles**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build 2>&1 | grep -E 'error:|BUILD'`
Expected: BUILD SUCCEEDED (or fix any missing FFI function names by checking the header).

- [ ] **Step 3: Commit**

```bash
git add Epistemos/Views/Notes/EmbeddedGraphNSView.swift
git commit -m "feat: add EmbeddedGraphNSView with Metal rendering and mouse events"
```

---

### Task 5: EmbeddedGraphView (NSViewRepresentable)

**Files:**
- Create: `Epistemos/Views/Notes/EmbeddedGraphView.swift`

- [ ] **Step 1: Create the SwiftUI wrapper**

Follow the pattern from `MetalGraphView.swift:12-37`:

```swift
// Epistemos/Views/Notes/EmbeddedGraphView.swift
import SwiftUI

/// SwiftUI wrapper for the embedded Metal graph view.
/// Injects EmbeddedGraphState and GraphStore from environment.
struct EmbeddedGraphView: NSViewRepresentable {

    @Environment(EmbeddedGraphState.self) private var embeddedGraphState
    @Environment(GraphState.self) private var graphState // for shared GraphStore

    /// Called when a node is tapped (single click). Show popover.
    var onNodeTap: ((String) -> Void)?

    /// Called when a node is double-clicked or "Open Note" from context menu.
    var onOpenNote: ((String) -> Void)?

    /// Called on background tap. Dismiss popover.
    var onBackgroundTap: (() -> Void)?

    func makeNSView(context: Context) -> EmbeddedGraphNSView {
        let view = EmbeddedGraphNSView(frame: .zero)
        view.embeddedGraphState = embeddedGraphState
        view.graphStore = graphState.store
        view.onNodeTap = onNodeTap
        view.onNodeDoubleTap = onOpenNote
        view.onBackgroundTap = onBackgroundTap
        return view
    }

    func updateNSView(_ nsView: EmbeddedGraphNSView, context: Context) {
        nsView.embeddedGraphState = embeddedGraphState
        nsView.graphStore = graphState.store
        nsView.onNodeTap = onNodeTap
        nsView.onNodeDoubleTap = onOpenNote
        nsView.onBackgroundTap = onBackgroundTap
        nsView.needsRender = true
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build 2>&1 | grep -E 'error:|BUILD'`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add Epistemos/Views/Notes/EmbeddedGraphView.swift
git commit -m "feat: add EmbeddedGraphView NSViewRepresentable wrapper"
```

---

## Chunk 3: UI Layer — Views and Routing

### Task 6: GraphNodePopover

**Files:**
- Create: `Epistemos/Views/Notes/GraphNodePopover.swift`

- [ ] **Step 1: Create the popover view**

```swift
// Epistemos/Views/Notes/GraphNodePopover.swift
import SwiftUI

/// Floating popover shown when a node is selected in the embedded graph.
struct GraphNodePopover: View {

    let nodeId: String
    let title: String
    let connectionCount: Int
    let lastModified: Date?
    let onOpenNote: () -> Void
    let onFocus: () -> Void

    @Environment(UIState.self) private var ui

    private var theme: EpistemosTheme { ui.theme }

    private var lastModifiedText: String {
        guard let date = lastModified else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return "Modified \(formatter.localizedString(for: date, relativeTo: Date()))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.epBody)
                .fontWeight(.semibold)
                .foregroundStyle(theme.textPrimary)
                .lineLimit(2)

            Text("\(connectionCount) connections" + (lastModified != nil ? " · \(lastModifiedText)" : ""))
                .font(.epCaption)
                .foregroundStyle(theme.textTertiary)

            HStack(spacing: 8) {
                Button("Open Note", action: onOpenNote)
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                Button("Focus", action: onFocus)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(12)
        .frame(minWidth: 180, maxWidth: 240)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build 2>&1 | grep -E 'error:|BUILD'`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add Epistemos/Views/Notes/GraphNodePopover.swift
git commit -m "feat: add GraphNodePopover for embedded graph node details"
```

---

### Task 7: GraphSplitView

**Files:**
- Create: `Epistemos/Views/Notes/GraphSplitView.swift`

- [ ] **Step 1: Create the resizable split view**

```swift
// Epistemos/Views/Notes/GraphSplitView.swift
import SwiftUI

/// Resizable horizontal split: editor (left) + embedded graph (right).
/// Divider is draggable. Ratio persisted via EmbeddedGraphState.splitRatio.
struct GraphSplitView<Editor: View, Graph: View>: View {

    @Environment(EmbeddedGraphState.self) private var embeddedGraphState

    @ViewBuilder let editor: () -> Editor
    @ViewBuilder let graph: () -> Graph

    @State private var isDragging = false

    var body: some View {
        GeometryReader { geometry in
            let editorWidth = geometry.size.width * embeddedGraphState.splitRatio
            let dividerWidth: CGFloat = 5

            HStack(spacing: 0) {
                editor()
                    .frame(width: editorWidth)

                // Draggable divider
                Rectangle()
                    .fill(isDragging ? Color.accentColor.opacity(0.4) : Color.primary.opacity(0.08))
                    .frame(width: dividerWidth)
                    .contentShape(Rectangle())
                    .onHover { hovering in
                        if hovering {
                            NSCursor.resizeLeftRight.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 1)
                            .onChanged { value in
                                isDragging = true
                                let newRatio = (editorWidth + value.translation.width) / geometry.size.width
                                embeddedGraphState.splitRatio = newRatio // clamping handled by didSet
                            }
                            .onEnded { _ in
                                isDragging = false
                                // Persist to UserDefaults
                                UserDefaults.standard.set(
                                    Double(embeddedGraphState.splitRatio),
                                    forKey: "embeddedGraph.splitRatio"
                                )
                            }
                    )

                graph()
                    .frame(maxWidth: .infinity)
            }
        }
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build 2>&1 | grep -E 'error:|BUILD'`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add Epistemos/Views/Notes/GraphSplitView.swift
git commit -m "feat: add GraphSplitView with resizable divider"
```

---

### Task 8: Wire Everything into NotesWorkspaceView

**Files:**
- Modify: `Epistemos/Views/Notes/NotesWorkspaceView.swift`

This is the critical integration task. Key areas to modify:
1. **Environment binding** — add `@Environment(EmbeddedGraphState.self)`
2. **Detail pane routing** — add graph tab and split mode branches
3. **Landing view** — replace "Most Recent" button callback with graph tab
4. **Tab bar** — show graph tab pill with graph icon

- [ ] **Step 1: Add environment binding**

At the top of `NotesWorkspaceView` (after line 8), add:

```swift
@Environment(EmbeddedGraphState.self) private var embeddedGraph
@Environment(GraphState.self) private var graphState // for shared GraphStore access
```

Note: `graphState` may already exist in `NotesWorkspaceView`. If so, skip adding it. Check the existing environment bindings first.

- [ ] **Step 2: Add @State for graph navigation and popover**

After the existing `@State` declarations (around line 14), add:

```swift
@State private var graphNavState = GraphNavigationState()
@State private var graphPopoverNodeId: String?
```

- [ ] **Step 3: Modify detail pane routing**

The existing `detailPane` (lines 91-131) needs new branches. The logic should be:

```swift
@ViewBuilder
private var detailPane: some View {
    if embeddedGraph.isSplitActive, let pageId = currentWorkspacePageId {
        // Split mode: editor left, graph right
        GraphSplitView {
            NoteDetailWorkspaceView(pageId: pageId, chrome: .embedded)
                .id(pageId)
        } graph: {
            embeddedGraphContent
        }
    } else if let tab = activeWorkspaceTab, tab.isGraphTab {
        // Standalone graph tab
        if let pageId = graphNavState.currentPageId {
            // Navigated into a note from graph
            NoteDetailWorkspaceView(pageId: pageId, chrome: .embedded)
                .id(pageId)
                .toolbar {
                    ToolbarItem(placement: .navigation) {
                        Button(action: {
                            graphNavState.back()
                        }) {
                            Label("Back to Graph", systemImage: "chevron.left")
                        }
                    }
                }
        } else {
            // At graph root — show the graph
            embeddedGraphContent
        }
    } else if let pageId = currentWorkspacePageId {
        // Normal note tab (existing behavior)
        // ... keep existing NoteDetailWorkspaceView routing ...
    } else {
        // Landing
        NotesWorkspaceLandingView(/* existing params */)
    }
}
```

**Important:** This requires careful integration with existing code. Read the full `detailPane` at lines 91-131 and the `activeNavigationState` logic before editing. The graph tab should NOT use `NoteNavigationState` — it uses `GraphNavigationState` instead.

- [ ] **Step 4: Add embeddedGraphContent helper**

```swift
@ViewBuilder
private var embeddedGraphContent: some View {
    GeometryReader { geometry in
        ZStack(alignment: .topLeading) {
            EmbeddedGraphView(
                onNodeTap: { nodeId in
                    graphPopoverNodeId = nodeId
                },
                onOpenNote: { nodeId in
                    openNoteFromGraph(nodeId)
                },
                onBackgroundTap: {
                    graphPopoverNodeId = nil
                }
            )

            // Graph controls overlay (top-left)
            graphControls

            // Popover — positioned near the node using graph_engine_node_screen_pos
            if let nodeId = graphPopoverNodeId,
               let node = graphState.store.nodes[nodeId] {
                GraphNodePopover(
                    nodeId: nodeId,
                    title: node.label,
                    connectionCount: graphState.store.adjacency[nodeId]?.count ?? 0,
                    lastModified: node.updatedAt,
                    onOpenNote: { openNoteFromGraph(nodeId) },
                    onFocus: {
                        graphPopoverNodeId = nil
                        focusGraphOnNode(nodeId)
                    }
                )
                .position(popoverPosition(for: nodeId, in: geometry))
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
    }
    .onAppear {
        loadGraphData()
    }
}
```

- [ ] **Step 5: Add graph controls (scope toggle + pin button)**

```swift
@ViewBuilder
private var graphControls: some View {
    HStack(spacing: 8) {
        // Scope toggle
        Picker("Scope", selection: Binding(
            get: {
                if case .global = embeddedGraph.scope { return 0 } else { return 1 }
            },
            set: { newValue in
                if newValue == 0 {
                    embeddedGraph.scope = .global
                } else if let pageId = currentWorkspacePageId ?? notesUI.workspacePageId {
                    embeddedGraph.scope = .local(noteId: pageId)
                }
                loadGraphData()
            }
        )) {
            Text("Global").tag(0)
            Text("Local").tag(1)
        }
        .pickerStyle(.segmented)
        .frame(width: 140)

        Spacer()

        if !embeddedGraph.isSplitActive {
            // Pin split button (only in standalone tab)
            Button {
                if let pageId = notesUI.workspacePageId {
                    embeddedGraph.activateSplit(focusingNoteId: pageId)
                } else {
                    // Open most recent page alongside graph
                    if let pageId = allPages.first?.id {
                        notesUI.openWorkspacePage(pageId)
                        embeddedGraph.activateSplit(focusingNoteId: pageId)
                    }
                }
            } label: {
                Label("Pin Split", systemImage: "rectangle.split.2x1")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        } else {
            // Unpin button (in split mode)
            Button {
                embeddedGraph.deactivateSplit()
            } label: {
                Label("Unpin", systemImage: "xmark.rectangle")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(.red)
        }
    }
    .padding(12)
}
```

- [ ] **Step 6: Add helper methods**

```swift
/// Compute popover position from node's screen coordinates.
/// Uses graph_engine_node_screen_pos(engine, uuid, out_xy) FFI call.
/// Falls back to center if engine unavailable.
private func popoverPosition(for nodeId: String, in geometry: GeometryProxy) -> CGPoint {
    guard let engine = embeddedGraph.engineHandle else {
        return CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
    }
    var posBuf: [Float] = [0, 0]
    let found = nodeId.withCString { uuid in
        graph_engine_node_screen_pos(engine, uuid, &posBuf)
    }
    guard found != 0 else {
        return CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
    }
    let scale = NSScreen.main?.backingScaleFactor ?? 2.0
    // Convert from pixel coords to view coords, clamp to view bounds
    let x = CGFloat(posBuf[0]) / scale
    let y = CGFloat(posBuf[1]) / scale
    let clampedX = min(max(x, 120), geometry.size.width - 120)
    let clampedY = min(max(y - 40, 60), geometry.size.height - 100) // offset above node
    return CGPoint(x: clampedX, y: clampedY)
}

private func focusGraphOnNode(_ nodeId: String) {
    guard let engine = embeddedGraph.engineHandle else { return }
    nodeId.withCString { uuid in
        graph_engine_center_on_node(engine, uuid)
    }
}

private func openNoteFromGraph(_ nodeId: String) {
    graphPopoverNodeId = nil
    // Find the note's title
    let title = graphState.store.nodes[nodeId]?.label ?? "Note"

    if embeddedGraph.isSplitActive {
        // In split mode: navigate the editor pane
        notesUI.setWorkspaceCurrentPage(nodeId)
        embeddedGraph.followNavigation(to: nodeId)
    } else {
        // In standalone tab: push onto graph nav stack
        graphNavState.pushNote(pageId: nodeId, title: title)
    }
}

private func loadGraphData() {
    // Post notification that scope changed — the EmbeddedGraphView's
    // updateNSView will detect scope changes and re-sync.
    // Alternatively, this triggers a state change that SwiftUI picks up.
    // The actual re-sync happens in updateNSView via scope observation.
    // Force a SwiftUI update by toggling a trivial state:
    embeddedGraph.focusedNodeId = embeddedGraph.focusedNodeId
}
```

- [ ] **Step 7: Replace "Most Recent" with "Open Graph" on landing view**

In the `NotesWorkspaceLandingView` instantiation (around line 113), change `onOpenMostRecent: openMostRecentPage` to `onOpenMostRecent: openGraphTab`.

Add the method:

```swift
private func openGraphTab() {
    notesUI.openGraphTab()
    embeddedGraph.isVisible = true
}
```

Then in `NotesWorkspaceLandingView` struct (around line 255-260), change the pill:

```swift
NotesLandingGlassPill(
    icon: "circle.grid.cross",  // graph icon
    label: "Graph",
    color: theme.accent,
    action: onOpenMostRecent    // reusing the existing callback name
)
// Remove .disabled(!hasRecentPage) and .opacity modifiers — graph is always available
```

- [ ] **Step 8: Update tab bar to show graph tab**

In the `NotesWorkspaceTabBar` tab iteration (around line 482-543), the existing code maps `workspaceTabs` to `TabItem`. Update the mapping to handle graph tabs:

When building tab items, check `tab.isGraphTab` and use:
- Icon: `"circle.grid.cross"` (or similar graph SF Symbol)
- Title: `"Graph"`

Additionally, when `embeddedGraph.isSplitActive` is true, show a **"GRAPH SPLIT"** indicator in the tab bar. This can be a small pill/badge next to the graph tab or a separate indicator element:

```swift
// After tab bar pills, show split indicator if active
if embeddedGraph.isSplitActive {
    Text("GRAPH SPLIT")
        .font(.system(size: 9, weight: .semibold))
        .foregroundStyle(theme.accent.opacity(0.8))
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(theme.accent.opacity(0.12))
        .clipShape(Capsule())
}
```

- [ ] **Step 9: Build and verify**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build 2>&1 | grep -E 'error:|BUILD'`
Expected: BUILD SUCCEEDED.

- [ ] **Step 10: Run full test suite**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test 2>&1 | tail -5`
Expected: All tests pass, no regressions.

- [ ] **Step 11: Commit**

```bash
git add Epistemos/Views/Notes/NotesWorkspaceView.swift
git commit -m "feat: wire embedded graph into workspace — tab routing, split mode, landing button"
```

---

## Chunk 4: Integration and Data Flow

### Task 9: Graph Data Loading on Tab Open

**Files:**
- Modify: `Epistemos/Views/Notes/EmbeddedGraphNSView.swift`
- Modify: `Epistemos/Views/Notes/EmbeddedGraphView.swift`

The graph needs to load data when:
1. Graph tab first appears (full sync)
2. Scope changes (global ↔ local)
3. GraphStore mutates (new note, wikilink edit)

- [ ] **Step 1: Add onAppear sync in EmbeddedGraphView**

Update `makeNSView` in `EmbeddedGraphView.swift` to trigger initial data load:

```swift
func makeNSView(context: Context) -> EmbeddedGraphNSView {
    let view = EmbeddedGraphNSView(frame: .zero)
    view.embeddedGraphState = embeddedGraphState
    view.graphStore = graphState.store
    view.onNodeTap = onNodeTap
    view.onNodeDoubleTap = onOpenNote
    view.onBackgroundTap = onBackgroundTap

    // Initial data load after Metal setup
    Task { @MainActor in
        switch embeddedGraphState.scope {
        case .global:
            view.syncFullGraph()
        case .local(let noteId):
            view.syncLocalGraph(centerNodeId: noteId)
        }
    }

    return view
}
```

- [ ] **Step 2: Add scope change observation**

In `EmbeddedGraphView.updateNSView`, detect scope changes and re-sync:

```swift
func updateNSView(_ nsView: EmbeddedGraphNSView, context: Context) {
    nsView.embeddedGraphState = embeddedGraphState
    nsView.graphStore = graphState.store
    nsView.onNodeTap = onNodeTap
    nsView.onNodeDoubleTap = onOpenNote
    nsView.onBackgroundTap = onBackgroundTap
    nsView.needsRender = true
}
```

Scope change re-sync should be triggered from the scope toggle in `graphControls` (already calls `loadGraphData()`). Implement `loadGraphData()` in `NotesWorkspaceView` to post a notification or directly access the NSView. The simplest approach: use `onChange(of: embeddedGraph.scope)` in the graph content view to re-sync.

- [ ] **Step 3: Add split navigation sync**

When split mode is active and the user navigates to a different note, the graph should re-center. Add in `NotesWorkspaceView`:

```swift
.onChange(of: currentWorkspacePageId) { _, newPageId in
    if embeddedGraph.isSplitActive, let pageId = newPageId {
        embeddedGraph.followNavigation(to: pageId)
    }
}
```

- [ ] **Step 4: Handle graph tab close while split active**

In the tab close handler (around the `onCloseTab` callback in `NotesWorkspaceView`), add:

```swift
// When closing the graph tab while split is active, collapse the split
if closedTab.isGraphTab {
    embeddedGraph.isSplitActive = false
    embeddedGraph.isVisible = false
}
```

- [ ] **Step 5: Build and test**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build 2>&1 | grep -E 'error:|BUILD'`
Expected: BUILD SUCCEEDED.

- [ ] **Step 6: Commit**

```bash
git add Epistemos/Views/Notes/EmbeddedGraphView.swift Epistemos/Views/Notes/EmbeddedGraphNSView.swift Epistemos/Views/Notes/NotesWorkspaceView.swift
git commit -m "feat: graph data loading, scope sync, split navigation tracking"
```

---

### Task 10: Vault Switch Cleanup

**Files:**
- Modify: `Epistemos/State/NotesUIState.swift`

- [ ] **Step 1: Write failing test**

Add to `EpistemosTests/NotesUIStateGraphTests.swift`:

```swift
@Test @MainActor func resetForVaultSwitchResetsEmbeddedGraphState() {
    let graphState = EmbeddedGraphState()
    graphState.isVisible = true
    graphState.isSplitActive = true
    graphState.scope = .local(noteId: "abc")

    graphState.resetForVaultSwitch()

    #expect(graphState.isVisible == false)
    #expect(graphState.isSplitActive == false)
    #expect(graphState.scope == .global)
}
```

This test already passes from Task 1. The integration test is that `AppBootstrap.resetForVaultSwitch()` also calls `embeddedGraphState.resetForVaultSwitch()`.

- [ ] **Step 2: Update AppBootstrap vault switch handler**

In `AppBootstrap.swift`, find where `notesUI.resetForVaultSwitch()` is called (around line 306) and add:

```swift
embeddedGraphState.resetForVaultSwitch()
```

- [ ] **Step 3: Build and test**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test 2>&1 | tail -5`
Expected: All tests pass.

- [ ] **Step 4: Commit**

```bash
git add Epistemos/App/AppBootstrap.swift EpistemosTests/NotesUIStateGraphTests.swift
git commit -m "feat: reset embedded graph state on vault switch"
```

---

### Task 11: Split Ratio Persistence

**Files:**
- Modify: `Epistemos/State/EmbeddedGraphState.swift`

- [ ] **Step 1: Add UserDefaults persistence**

In `EmbeddedGraphState.init()`, load persisted ratio:

```swift
init() {
    let saved = UserDefaults.standard.double(forKey: "embeddedGraph.splitRatio")
    if saved > 0 {
        splitRatio = CGFloat(saved)
    }
}
```

The save is already handled in `GraphSplitView`'s drag gesture `onEnded`.

- [ ] **Step 2: Verify it compiles and test**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build 2>&1 | grep -E 'error:|BUILD'`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add Epistemos/State/EmbeddedGraphState.swift
git commit -m "feat: persist split ratio across sessions via UserDefaults"
```

---

## Chunk 5: Final Integration Test

### Task 12: Add Xcode Project References + End-to-End Verification

**Files:**
- Modify: `Epistemos.xcodeproj/project.pbxproj` (automatically by Xcode)

- [ ] **Step 1: Ensure all new files are in the Xcode project**

All 6 new files must be added to the Epistemos target:
1. `Epistemos/State/EmbeddedGraphState.swift`
2. `Epistemos/State/GraphNavigationState.swift`
3. `Epistemos/Views/Notes/EmbeddedGraphNSView.swift`
4. `Epistemos/Views/Notes/EmbeddedGraphView.swift`
5. `Epistemos/Views/Notes/GraphNodePopover.swift`
6. `Epistemos/Views/Notes/GraphSplitView.swift`

And 3 test files to the EpistemosTests target:
1. `EpistemosTests/EmbeddedGraphStateTests.swift`
2. `EpistemosTests/GraphNavigationStateTests.swift`
3. `EpistemosTests/NotesUIStateGraphTests.swift`

If using `xcodebuild`, files should be auto-discovered if they're in the right directories. If not, manually add via Xcode or use `ruby` script to update `project.pbxproj`.

- [ ] **Step 2: Full build**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build 2>&1 | tail -10`
Expected: BUILD SUCCEEDED with no warnings on new files.

- [ ] **Step 3: Full test suite**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test 2>&1 | tail -10`
Expected: All tests pass (existing + 17 new tests).

- [ ] **Step 4: Rust tests still pass**

Run: `cd graph-engine && cargo test 2>&1 | tail -5`
Expected: All 549 tests pass (no Rust changes in this feature).

- [ ] **Step 5: Final commit**

```bash
git add -A
git commit -m "feat: embedded graph view — complete integration

Adds embedded graph to Notes workspace:
- Graph tab (standalone, global view)
- Pinned split mode (resizable, local graph)
- Node popover, right-click context menu
- Navigation stack (graph → note → back)
- Scope toggle (global/local)
- Split ratio persistence
- Vault switch cleanup"
```
