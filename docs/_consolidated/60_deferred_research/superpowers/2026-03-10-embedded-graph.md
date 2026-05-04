# Embedded Graph Implementation Plan (v2)

> **Index status**: DEFERRED-RESEARCH — Vision/embedded-graph deferred; W9.24 graph embedding spec.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md). Copy in `docs/_consolidated/60_deferred_research/superpowers/`.



> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an embedded graph view to the note window system — as a native macOS tab in the existing tab group and as a pinnable right-side split within note tabs — reusing the Metal + Rust FFI rendering pipeline.

**Architecture:** Notes are standalone NSWindows in a native tab group managed by `NoteWindowManager`. The graph opens as another tab in that group (via a new `openGraphTab()` method). Split mode embeds the graph within a `NoteTabShell` alongside the editor. New `EmbeddedGraphState` (@Observable) owns a separate Rust engine handle. New `EmbeddedGraphNSView` (NSView subclass) renders via Metal, following `MetalGraphNSView` patterns. Shared `GraphStore` provides data — no duplication.

**Tech Stack:** Swift, SwiftUI, AppKit (NSWindow/NSView/NSViewRepresentable), Metal, Rust FFI (`graph-engine`)

**Spec:** Original spec at `5ed9327` (git) — updated for actual architecture below.

---

## Actual Codebase Architecture (as scanned)

**How notes work now:**
- `NoteWindowManager` (singleton) creates NSWindows with `tabbingIdentifier: "epistemos-note-tabs"`
- Each window contains `NoteTabShell` → `NoteDetailWorkspaceView` (2437-line editor view)
- `NoteTabShell` owns `NoteNavigationState` for breadcrumb wikilink nav
- `NotesUIState` is minimal: `activePageId`, search, UI flags — NO workspace tabs
- Landing view is `Views/Landing/LandingView.swift` (separate from notes)
- Notes sidebar is a floating `NSPanel` via `UtilityWindowManager`
- `AppEnvironment.withAppEnvironment(bootstrap)` for environment injection

**How the graph overlay works now:**
- `HologramOverlay` creates a full-screen `NSPanel` child window
- `MetalGraphNSView` (1400+ lines) owns engine, CVDisplayLink, render loop
- `MetalGraphView` is NSViewRepresentable wrapper injecting `GraphState` from environment
- `GraphState` has `store: GraphStore`, `filter: FilterEngine`, version-based dirty tracking
- Batch FFI: `graph_engine_add_nodes_batch` / `add_edges_batch` for data loading
- `graph_engine_render(engine, UInt32 width, UInt32 height)` returns 0=idle, 1=more

---

## File Map

### New Files

| File | Responsibility |
|------|---------------|
| `Epistemos/State/EmbeddedGraphState.swift` | @Observable state: visibility, split, scope, engine handle, hover, splitRatio |
| `Epistemos/Views/Notes/EmbeddedGraphNSView.swift` | NSView subclass: CAMetalLayer + own GraphEngine, 30Hz display link, mouse events, context menu |
| `Epistemos/Views/Notes/EmbeddedGraphView.swift` | NSViewRepresentable wrapping EmbeddedGraphNSView for SwiftUI |
| `Epistemos/Views/Notes/GraphNodePopover.swift` | SwiftUI popover: title, connections, last modified, "Open Note" / "Focus" buttons |
| `Epistemos/Views/Notes/GraphSplitView.swift` | Resizable HStack: editor left, graph right, draggable divider |
| `Epistemos/Views/Notes/GraphTabShell.swift` | SwiftUI view for graph-as-tab: graph root + note drill-in with back button |

### Modified Files

| File | Change |
|------|--------|
| `Epistemos/Views/Notes/NoteWindowManager.swift` | Add `openGraphTab()` method, graph window tracking, `GraphNavigationState` |
| `Epistemos/Views/Notes/NoteDetailWorkspaceView.swift` | Add split mode toggle (toolbar button), conditionally wrap in `GraphSplitView` |
| `Epistemos/Views/Landing/LandingView.swift` | Add "Open Graph" shortcut/button (replaces or adds to existing shortcuts) |
| `Epistemos/App/AppBootstrap.swift` | Create `EmbeddedGraphState` instance, vault switch reset |
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
        state.isSplitActive = true
        state.scope = .local(noteId: "abc")
        state.focusedNodeId = "xyz"
        state.hoveredNodeId = "xyz"

        state.resetForVaultSwitch()

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
        #expect(state.scope == .global)
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

    var isSplitActive = false
    var scope: EmbeddedGraphScope = .global
    var focusedNodeId: String?
    var hoveredNodeId: String?

    nonisolated(unsafe) var engineHandle: OpaquePointer?

    var splitRatio: CGFloat = 0.55 {
        didSet {
            let clamped = min(0.8, max(0.3, splitRatio))
            if splitRatio != clamped { splitRatio = clamped }
        }
    }

    init() {
        let saved = UserDefaults.standard.double(forKey: "embeddedGraph.splitRatio")
        if saved > 0 { splitRatio = CGFloat(saved) }
    }

    func activateSplit(focusingNoteId noteId: String) {
        isSplitActive = true
        scope = .local(noteId: noteId)
        focusedNodeId = noteId
    }

    func deactivateSplit() {
        isSplitActive = false
        scope = .global
    }

    func followNavigation(to noteId: String) {
        focusedNodeId = noteId
        if case .local = scope {
            scope = .local(noteId: noteId)
        }
    }

    func resetForVaultSwitch() {
        isSplitActive = false
        scope = .global
        focusedNodeId = nil
        hoveredNodeId = nil
    }
}
```

- [ ] **Step 4: Run tests — verify they pass**
- [ ] **Step 5: Commit**

---

### Task 2: Wire State into AppBootstrap + AppEnvironment

**Files:**
- Modify: `Epistemos/App/AppBootstrap.swift`
- Modify: `Epistemos/App/AppEnvironment.swift`

- [ ] **Step 1: Add `embeddedGraphState` to AppBootstrap**

After `let physicsCoordinator = PhysicsCoordinator()`, add:

```swift
let embeddedGraphState = EmbeddedGraphState()
```

In the vault switch reset method (where `notesUI.resetForVaultSwitch()` is called), add:

```swift
embeddedGraphState.resetForVaultSwitch()
```

- [ ] **Step 2: Add to AppEnvironment**

In `withAppEnvironment`, add before closing:

```swift
.environment(bootstrap.embeddedGraphState)
```

- [ ] **Step 3: Build and verify**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build 2>&1 | grep -E 'error:|BUILD'`
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

---

## Chunk 2: Metal Rendering Layer

### Task 3: EmbeddedGraphNSView

**Files:**
- Create: `Epistemos/Views/Notes/EmbeddedGraphNSView.swift`

**Context:** Follows `MetalGraphNSView` patterns. Key differences: reads from `EmbeddedGraphState` (not `GraphState`), 30Hz tick, lite mode, opaque background. Uses batch FFI for data loading.

**FFI functions used (all verified against `graph-engine-bridge/graph_engine.h`):**
`graph_engine_create`, `graph_engine_destroy`, `graph_engine_clear`, `graph_engine_add_nodes_batch`, `graph_engine_add_edges_batch`, `graph_engine_commit`, `graph_engine_render(engine, uint32_t, uint32_t)`, `graph_engine_mouse_down`, `graph_engine_mouse_up`, `graph_engine_mouse_moved`, `graph_engine_scroll(engine, delta_x, delta_y)`, `graph_engine_magnify(engine, screen_x, screen_y, magnification)`, `graph_engine_hovered_node_uuid`, `graph_engine_center_on_node`, `graph_engine_highlight_neighbors`, `graph_engine_node_screen_pos`, `graph_engine_pause`, `graph_engine_resume`, `graph_engine_set_lite_mode`, `graph_engine_set_clear_color`, `graph_engine_set_light_mode`.

- [ ] **Step 1: Create EmbeddedGraphNSView**

```swift
// Epistemos/Views/Notes/EmbeddedGraphNSView.swift
import Cocoa
import MetalKit
import Synchronization

final class EmbeddedGraphNSView: NSView {

    // MARK: - Engine & Rendering

    nonisolated(unsafe) private var engine: OpaquePointer?
    nonisolated(unsafe) private var displayLink: CVDisplayLink?
    private var metalLayer: CAMetalLayer?
    nonisolated(unsafe) private let framePending = Atomic<Bool>(false)
    nonisolated(unsafe) private let renderNeeded = Atomic<Bool>(true)
    nonisolated(unsafe) private let isInvalidated = Atomic<Bool>(false)

    nonisolated(unsafe) var embeddedGraphState: EmbeddedGraphState?
    nonisolated(unsafe) var graphStore: GraphStore?

    // MARK: - Callbacks

    var onNodeTap: ((String) -> Void)?
    var onNodeDoubleTap: ((String) -> Void)?
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
        layer.isOpaque = true
        metalLayer = layer

        let devicePtr = Unmanaged.passUnretained(device).toOpaque()
        let layerPtr = Unmanaged.passUnretained(layer).toOpaque()
        engine = graph_engine_create(devicePtr, layerPtr)

        // Lite mode: simplified rendering, lower GPU usage
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

        CVDisplayLinkSetOutputHandler(dl) { [weak self] _, _, _, _, _ -> CVReturn in
            guard !isInvalidated.load(ordering: .acquire) else { return kCVReturnSuccess }
            counter += 1
            guard counter % 2 == 0 else { return kCVReturnSuccess } // 30Hz
            guard !framePending.load(ordering: .relaxed) else { return kCVReturnSuccess }
            framePending.store(true, ordering: .relaxed)
            Task { @MainActor [weak self] in
                self?.renderFrame()
            }
            return kCVReturnSuccess
        }
        CVDisplayLinkStart(dl)
    }

    private func stopDisplayLink() {
        guard let dl = displayLink else { return }
        CVDisplayLinkStop(dl)
        displayLink = nil
    }

    @MainActor private func renderFrame() {
        defer { framePending.store(false, ordering: .relaxed) }
        guard !isInvalidated.load(ordering: .acquire),
              let engine,
              let layer = metalLayer else { return }

        let size = layer.drawableSize
        let w = UInt32(size.width)
        let h = UInt32(size.height)
        guard w > 0, h > 0 else { return }

        let needsMore = graph_engine_render(engine, w, h)
        if needsMore == 0 {
            renderNeeded.store(false, ordering: .relaxed)
        }
    }

    // MARK: - Data Loading (Batch FFI)

    func syncFullGraph() {
        guard let engine, let store = graphStore else { return }
        graph_engine_clear(engine)
        commitNodes(Array(store.nodes.values), store: store)
        commitEdges(Array(store.edges.values), store: store)
        graph_engine_commit(engine, 1)
        needsRender = true
    }

    func syncLocalGraph(centerNodeId: String, depth: Int = 2) {
        guard let engine, let store = graphStore else { return }
        graph_engine_clear(engine)

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

        commitNodes(visited.compactMap { store.nodes[$0] }, store: store)
        commitEdges(store.edges.values.filter {
            visited.contains($0.sourceNodeId) && visited.contains($0.targetNodeId)
        }.map { $0 }, store: store)

        graph_engine_commit(engine, 1)
        centerNodeId.withCString { graph_engine_center_on_node(engine, $0) }
        needsRender = true
    }

    private func commitNodes(_ nodes: [GraphNodeRecord], store: GraphStore) {
        guard let engine, !nodes.isEmpty else { return }
        // See MetalGraphNSView.commitGraphData() for exact batch pattern.
        // Uses graph_engine_add_nodes_batch with:
        //   node.type.rustIndex (UInt8), store.linkCount(for:) (UInt32)
        // Full batch FFI pattern copied from MetalGraphView.swift lines 254-306.
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
                                    engine, uPtrs.baseAddress, xs.baseAddress,
                                    ys.baseAddress, types.baseAddress,
                                    links.baseAddress, lPtrs.baseAddress,
                                    UInt32(nodes.count)
                                )
                            }
                        }
                    }
                }
            }
        }
    }

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
                            engine, sPtrs.baseAddress, tPtrs.baseAddress,
                            wts.baseAddress, types.baseAddress,
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
        needsRender = true
    }

    // MARK: - Mouse Events

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        if window?.firstResponder !== self { window?.makeFirstResponder(self) }
        guard let engine else { return }
        let loc = convert(event.locationInWindow, from: nil)
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
        let loc = convert(event.locationInWindow, from: nil)
        let scale = metalLayer?.contentsScale ?? 2.0
        let sx = Float(loc.x * scale)
        let sy = Float((bounds.height - loc.y) * scale)

        // Detect click vs drag by comparing mouse-down vs mouse-up position
        if event.clickCount >= 2 {
            if let uuidPtr = graph_engine_hovered_node_uuid(engine) {
                onNodeDoubleTap?(String(cString: uuidPtr))
            }
        } else {
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
        needsRender = true
    }

    override func mouseMoved(with event: NSEvent) {
        guard let engine else { return }
        let loc = convert(event.locationInWindow, from: nil)
        let scale = metalLayer?.contentsScale ?? 2.0
        graph_engine_mouse_moved(engine, Float(loc.x * scale), Float((bounds.height - loc.y) * scale))
        if let uuidPtr = graph_engine_hovered_node_uuid(engine) {
            Task { @MainActor [weak self] in
                self?.embeddedGraphState?.hoveredNodeId = String(cString: uuidPtr)
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
            // Option+scroll = pan
            graph_engine_scroll(engine, Float(event.scrollingDeltaX), Float(event.scrollingDeltaY))
        } else {
            // Default scroll = zoom
            graph_engine_magnify(engine, sx, sy, Float(event.scrollingDeltaY) * 0.01)
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
            nodeId.withCString { graph_engine_center_on_node(engine, $0) }
        }
        needsRender = true
    }

    @objc private func contextShowConnections(_ sender: NSMenuItem) {
        guard let nodeId = sender.representedObject as? String else { return }
        if let engine {
            nodeId.withCString { graph_engine_highlight_neighbors(engine, $0) }
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

    func pauseEngine() {
        guard let engine else { return }
        graph_engine_pause(engine)
    }

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
            owner: self, userInfo: nil
        ))
    }
}
```

- [ ] **Step 2: Verify it compiles**
- [ ] **Step 3: Commit**

---

### Task 4: EmbeddedGraphView (NSViewRepresentable)

**Files:**
- Create: `Epistemos/Views/Notes/EmbeddedGraphView.swift`

- [ ] **Step 1: Create the SwiftUI wrapper**

```swift
// Epistemos/Views/Notes/EmbeddedGraphView.swift
import SwiftUI

struct EmbeddedGraphView: NSViewRepresentable {

    @Environment(EmbeddedGraphState.self) private var embeddedGraphState
    @Environment(GraphState.self) private var graphState

    var onNodeTap: ((String) -> Void)?
    var onOpenNote: ((String) -> Void)?
    var onBackgroundTap: (() -> Void)?

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
- [ ] **Step 3: Commit**

---

## Chunk 3: UI Views

### Task 5: GraphNodePopover

**Files:**
- Create: `Epistemos/Views/Notes/GraphNodePopover.swift`

- [ ] **Step 1: Create the popover view**

Floating popover with: title, connection count, last modified (`node.updatedAt`), "Open Note" and "Focus" buttons. Uses `.ultraThinMaterial` background, small rounded rectangle.

- [ ] **Step 2: Verify it compiles**
- [ ] **Step 3: Commit**

---

### Task 6: GraphSplitView

**Files:**
- Create: `Epistemos/Views/Notes/GraphSplitView.swift`

- [ ] **Step 1: Create the resizable split view**

Generic `GraphSplitView<Editor: View, Graph: View>` with:
- `@Environment(EmbeddedGraphState.self)` for `splitRatio`
- GeometryReader-based layout: editor width = `geometry.size.width * splitRatio`
- Draggable divider (5px, `NSCursor.resizeLeftRight` on hover)
- DragGesture updates `splitRatio` (clamping handled by didSet)
- On drag end: persist to `UserDefaults("embeddedGraph.splitRatio")`

- [ ] **Step 2: Verify it compiles**
- [ ] **Step 3: Commit**

---

### Task 7: GraphTabShell

**Files:**
- Create: `Epistemos/Views/Notes/GraphTabShell.swift`

**Context:** This is the SwiftUI root for the graph-as-a-tab. It lives inside the NSWindow content (same pattern as `NoteTabShell`). It shows the graph at root, or a note editor when the user drills in.

- [ ] **Step 1: Create GraphTabShell**

```swift
// Epistemos/Views/Notes/GraphTabShell.swift
import SwiftUI

/// Root view for the graph tab in the native note window tab group.
/// Shows embedded graph at root. Double-clicking a node pushes a note editor.
/// Back button returns to graph.
struct GraphTabShell: View {

    @Environment(EmbeddedGraphState.self) private var embeddedGraph
    @Environment(GraphState.self) private var graphState

    @State private var noteStack: [String] = [] // pageId stack
    @State private var popoverNodeId: String?

    private var isAtGraphRoot: Bool { noteStack.isEmpty }
    private var currentPageId: String? { noteStack.last }

    var body: some View {
        Group {
            if let pageId = currentPageId {
                // Drilled into a note
                NoteDetailWorkspaceView(pageId: pageId)
                    .id(pageId)
                    .toolbar {
                        ToolbarItem(placement: .navigation) {
                            Button {
                                noteStack.removeLast()
                            } label: {
                                Label("Back to Graph", systemImage: "chevron.left")
                            }
                        }
                    }
            } else {
                // Graph root
                graphContent
            }
        }
    }

    @ViewBuilder
    private var graphContent: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                EmbeddedGraphView(
                    onNodeTap: { nodeId in
                        popoverNodeId = nodeId
                    },
                    onOpenNote: { nodeId in
                        openNoteFromGraph(nodeId)
                    },
                    onBackgroundTap: {
                        popoverNodeId = nil
                    }
                )

                graphControls

                if let nodeId = popoverNodeId,
                   let node = graphState.store.nodes[nodeId] {
                    GraphNodePopover(
                        nodeId: nodeId,
                        title: node.label,
                        connectionCount: graphState.store.adjacency[nodeId]?.count ?? 0,
                        lastModified: node.updatedAt,
                        onOpenNote: { openNoteFromGraph(nodeId) },
                        onFocus: {
                            popoverNodeId = nil
                            focusOnNode(nodeId)
                        }
                    )
                    .position(popoverPosition(for: nodeId, in: geometry))
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
        }
    }

    @ViewBuilder
    private var graphControls: some View {
        HStack(spacing: 8) {
            // Scope toggle
            Picker("Scope", selection: Binding(
                get: { if case .global = embeddedGraph.scope { return 0 } else { return 1 } },
                set: { newValue in
                    if newValue == 0 {
                        embeddedGraph.scope = .global
                    } else if let focused = embeddedGraph.focusedNodeId {
                        embeddedGraph.scope = .local(noteId: focused)
                    }
                }
            )) {
                Text("Global").tag(0)
                Text("Local").tag(1)
            }
            .pickerStyle(.segmented)
            .frame(width: 140)

            Spacer()

            // Pin split button
            Button {
                // Find or open a note to split with — use notesUI.activePageId
                if let activeId = AppBootstrap.shared?.notesUI.activePageId {
                    embeddedGraph.activateSplit(focusingNoteId: activeId)
                }
            } label: {
                Label("Pin Split", systemImage: "rectangle.split.2x1")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(12)
    }

    private func openNoteFromGraph(_ nodeId: String) {
        popoverNodeId = nil
        noteStack.append(nodeId)
    }

    private func focusOnNode(_ nodeId: String) {
        guard let engine = embeddedGraph.engineHandle else { return }
        nodeId.withCString { graph_engine_center_on_node(engine, $0) }
    }

    private func popoverPosition(for nodeId: String, in geometry: GeometryProxy) -> CGPoint {
        guard let engine = embeddedGraph.engineHandle else {
            return CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        var posBuf: [Float] = [0, 0]
        let found = nodeId.withCString { graph_engine_node_screen_pos(engine, $0, &posBuf) }
        guard found != 0 else {
            return CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        let x = min(max(CGFloat(posBuf[0]) / scale, 120), geometry.size.width - 120)
        let y = min(max(CGFloat(posBuf[1]) / scale - 40, 60), geometry.size.height - 100)
        return CGPoint(x: x, y: y)
    }
}
```

- [ ] **Step 2: Verify it compiles**
- [ ] **Step 3: Commit**

---

## Chunk 4: Integration

### Task 8: NoteWindowManager — Open Graph Tab

**Files:**
- Modify: `Epistemos/Views/Notes/NoteWindowManager.swift`

- [ ] **Step 1: Add `openGraphTab()` to NoteWindowManager**

Follow the same pattern as `openWindow(for page:)` but instead of `NoteTabShell`, use `GraphTabShell`:

```swift
// In NoteWindowManager, after openWindow(for:) method:

/// Open the embedded graph as a tab in the note window tab group.
/// Reuses existing graph window if one is already open.
func openGraphTab() {
    // Check if graph tab already exists
    let graphKey = "__graph__"
    if let existing = windows[graphKey], existing.isVisible {
        existing.makeKeyAndOrderFront(nil)
        return
    }

    guard let bootstrap = AppBootstrap.shared else { return }

    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0,
                            width: Self.noteDefaultFrameSize.width,
                            height: Self.noteDefaultFrameSize.height),
        styleMask: [.titled, .closable, .resizable, .miniaturizable],
        backing: .buffered, defer: false
    )
    window.title = "Graph"
    window.center()
    window.isReleasedWhenClosed = false
    window.minSize = Self.noteMinimumFrameSize
    window.tabbingMode = .preferred
    window.tabbingIdentifier = "epistemos-note-tabs"
    window.delegate = tabDelegate

    let graphView = GraphTabShell()
        .withAppEnvironment(bootstrap)
        .modelContainer(bootstrap.modelContainer)
    let hostingController = NSHostingController(rootView: graphView)
    hostingController.sceneBridgingOptions = [.all]
    window.contentViewController = hostingController

    NoteWindowChrome.apply(to: window, toolbarIdentifier: "NoteEditor")
    let theme = bootstrap.uiState.theme
    window.appearance = NSAppearance(named: theme.isDark ? .darkAqua : .aqua)
    window.backgroundColor = theme.nsBackground
    WindowPresentationPolicy.applyModularZoomBehavior(to: window)

    let observer = NotificationCenter.default.addObserver(
        forName: NSWindow.willCloseNotification,
        object: window, queue: .main
    ) { [weak self] notification in
        guard let window = notification.object as? NSWindow else { return }
        Task { @MainActor in
            self?.handleWindowClose(window, pageId: graphKey)
        }
    }
    observers[graphKey] = observer

    if let existingWindow = windows.values.first {
        existingWindow.addTabbedWindow(window, ordered: .above)
    }
    window.makeKeyAndOrderFront(nil)
    windows[graphKey] = window
}
```

- [ ] **Step 2: Handle graph tab in NoteTabDelegate.windowDidBecomeMain**

When the graph tab becomes main, don't try to sync `activePageId`:

```swift
// In NoteTabDelegate.windowDidBecomeMain:
// Check if window is the graph tab — if so, skip activePageId sync
let pageId = NoteWindowManager.shared.pageId(for: window)
if pageId == "__graph__" { return }
```

- [ ] **Step 3: Build and verify**
- [ ] **Step 4: Commit**

---

### Task 9: Landing View — Add Graph Entry Point

**Files:**
- Modify: `Epistemos/Views/Landing/LandingView.swift`

- [ ] **Step 1: Add "Open Graph" hidden shortcut or button**

Add alongside the existing Cmd+N (new note) shortcut. Could be:
- A visible button in the greeting area
- Or a keyboard shortcut (e.g., Cmd+G if not taken by overlay toggle)

Read `LandingView.swift` fully to find the best insertion point. The greeting area has shortcut hints. Add a graph entry that calls `NoteWindowManager.shared.openGraphTab()`.

- [ ] **Step 2: Build and verify**
- [ ] **Step 3: Commit**

---

### Task 10: Split Mode in NoteDetailWorkspaceView

**Files:**
- Modify: `Epistemos/Views/Notes/NoteDetailWorkspaceView.swift`

**Context:** When `embeddedGraph.isSplitActive`, the note editor should be wrapped in `GraphSplitView` with the graph on the right. This affects `NoteDetailWorkspaceView` body layout.

- [ ] **Step 1: Add `@Environment(EmbeddedGraphState.self)` to NoteDetailWorkspaceView**

Read the full body of `NoteDetailWorkspaceView` to understand where to inject the split. The approach:

```swift
// In NoteDetailWorkspaceView body, wrap the entire content:
if embeddedGraph.isSplitActive {
    GraphSplitView {
        existingEditorContent
    } graph: {
        EmbeddedGraphView(
            onNodeTap: { nodeId in /* show popover */ },
            onOpenNote: { nodeId in
                // Navigate to note — use wikilink navigation
                // Push onto NoteNavigationState
            },
            onBackgroundTap: { /* dismiss popover */ }
        )
    }
} else {
    existingEditorContent
}
```

Key: The split graph should auto-follow navigation. Add:
```swift
.onChange(of: navState?.currentPageId) { _, newId in
    if embeddedGraph.isSplitActive, let pageId = newId {
        embeddedGraph.followNavigation(to: pageId)
    }
}
```

- [ ] **Step 2: Add "Unpin Split" toolbar button when split is active**

In the toolbar section, add conditionally:
```swift
if embeddedGraph.isSplitActive {
    ToolbarItem(placement: .primaryAction) {
        Button {
            embeddedGraph.deactivateSplit()
        } label: {
            Label("Close Graph", systemImage: "xmark.rectangle")
        }
    }
}
```

- [ ] **Step 3: Build and verify**
- [ ] **Step 4: Run full test suite**
- [ ] **Step 5: Commit**

---

### Task 11: Vault Switch Cleanup

**Files:**
- Modify: `Epistemos/App/AppBootstrap.swift` (already done in Task 2)

Verify `embeddedGraphState.resetForVaultSwitch()` is called alongside `notesUI.resetForVaultSwitch()`. Also close the graph tab window if open:

```swift
NoteWindowManager.shared.closeGraphTab() // New method — removes __graph__ window
```

- [ ] **Step 1: Add `closeGraphTab()` to NoteWindowManager**
- [ ] **Step 2: Call from vault switch reset**
- [ ] **Step 3: Commit**

---

## Chunk 5: Final Verification

### Task 12: End-to-End Build and Test

- [ ] **Step 1: Ensure all new files are in the Xcode project**

6 new files + 1 test file must be in targets.

- [ ] **Step 2: Full build**

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build 2>&1 | tail -10
```

- [ ] **Step 3: Full test suite**

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test 2>&1 | tail -10
```

- [ ] **Step 4: Rust tests**

```bash
cd graph-engine && cargo test 2>&1 | tail -5
```

- [ ] **Step 5: Final commit**
