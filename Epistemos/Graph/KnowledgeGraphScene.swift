import SpriteKit

// MARK: - KnowledgeGraphScene
// Main SKScene subclass that renders the knowledge graph with viewport culling
// and node/edge pooling. Integrates with GraphStore, FilterEngine, and ForceSimulation.

final class KnowledgeGraphScene: SKScene {

    // MARK: - Static Node Colors

    static let nodeColors: [GraphNodeType: NSColor] = [
        .note: .systemBlue,
        .folder: .systemGray,
        .idea: .systemYellow,
        .brainDump: .systemPurple,
        .chat: .systemGreen,
        .insight: .systemTeal,
        .thinker: .systemOrange,
        .paper: .systemRed,
        .book: .systemBrown,
        .source: .systemIndigo,
        .concept: .systemPink,
        .tag: .tertiaryLabelColor,
        .quote: .systemCyan,
    ]

    // MARK: - External State (set before presenting)

    var graphStore: GraphStore?
    var filterEngine: FilterEngine?
    var forceSimulation: ForceSimulation?

    // MARK: - Callbacks

    var onNodeSelected: ((String) -> Void)?
    var onNodeRightClicked: ((String, CGPoint) -> Void)?
    var onBackgroundClicked: (() -> Void)?

    // MARK: - Layers

    private let edgeLayer = SKNode()
    private let nodeLayer = SKNode()
    private let cameraNode = SKCameraNode()

    // MARK: - Node Pool

    private var activeSprites: [String: GraphNodeSprite] = [:]
    private var spritePool: [GraphNodeSprite] = []
    private let maxPoolSize = 400

    // MARK: - Edge Pool

    private var activeEdges: [String: SKShapeNode] = [:]
    private var edgePool: [SKShapeNode] = []

    // MARK: - Interaction State

    private(set) var selectedNodeId: String?
    private var hoveredNodeId: String?
    private var draggedNodeId: String?
    private var lastMousePosition: CGPoint?

    // MARK: - Simulation Loop

    private var simulationTask: Task<Void, Never>?

    // MARK: - Scene Lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = .clear
        anchorPoint = CGPoint(x: 0.5, y: 0.5)

        // Layer hierarchy
        edgeLayer.zPosition = 0
        nodeLayer.zPosition = 1
        addChild(edgeLayer)
        addChild(nodeLayer)

        // Camera
        camera = cameraNode
        addChild(cameraNode)

        // Pre-populate sprite pool
        for _ in 0..<maxPoolSize {
            let sprite = GraphNodeSprite()
            sprite.isHidden = true
            sprite.alpha = 0
            nodeLayer.addChild(sprite)
            spritePool.append(sprite)
        }

        // Performance
        view.ignoresSiblingOrder = true

        // Start simulation
        startSimulationLoop()
    }

    override func willMove(from view: SKView) {
        simulationTask?.cancel()
        simulationTask = nil
    }

    // MARK: - Simulation Loop

    private func startSimulationLoop() {
        simulationTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }

                if let sim = self.forceSimulation {
                    // Tick on the ForceSimulation actor
                    let positions = await sim.tick()

                    // Apply positions back on MainActor (we are already on MainActor
                    // since KnowledgeGraphScene is @MainActor via SKScene)
                    if let store = self.graphStore {
                        for (nodeId, pos) in positions {
                            store.updatePosition(nodeId, position: pos)
                        }
                    }
                }

                self.updateViewport()

                // ~30fps physics
                try? await Task.sleep(for: .milliseconds(33))
            }
        }
    }

    // MARK: - Viewport Culling

    func updateViewport() {
        guard let store = graphStore else { return }

        let visibleRect = calculateVisibleRect()

        // Determine which nodes should be active
        var shouldBeActive = Set<String>()

        for (nodeId, record) in store.nodes {
            // Check filter visibility
            let passesFilter: Bool
            if let filter = filterEngine {
                passesFilter = filter.isNodeVisible(record)
            } else {
                passesFilter = true
            }

            guard passesFilter else { continue }

            // Check viewport containment
            let nodePoint = CGPoint(x: CGFloat(record.position.x), y: CGFloat(record.position.y))
            guard visibleRect.contains(nodePoint) else { continue }

            shouldBeActive.insert(nodeId)
        }

        // Recycle sprites for nodes that left viewport or became filtered out
        let toRecycle = Set(activeSprites.keys).subtracting(shouldBeActive)
        for nodeId in toRecycle {
            if let sprite = activeSprites.removeValue(forKey: nodeId) {
                sprite.recycle()
                spritePool.append(sprite)
            }
        }

        // Assign sprites from pool for newly visible nodes
        let toActivate = shouldBeActive.subtracting(Set(activeSprites.keys))
        for nodeId in toActivate {
            guard let record = store.nodes[nodeId] else { continue }
            guard let sprite = spritePool.popLast() else { break } // Pool exhausted

            let color = Self.nodeColors[record.type] ?? .systemGray
            let radius = radiusForWeight(record.weight)
            sprite.configure(record: record, color: color, radius: radius, showLabel: true)
            activeSprites[nodeId] = sprite
        }

        // Update positions for all active sprites
        for (nodeId, sprite) in activeSprites {
            guard let record = store.nodes[nodeId] else { continue }
            sprite.position = CGPoint(x: CGFloat(record.position.x), y: CGFloat(record.position.y))
        }

        // Update edges
        updateEdges()
    }

    private func calculateVisibleRect() -> CGRect {
        guard let view else { return CGRect(x: -1000, y: -1000, width: 2000, height: 2000) }

        let scale = cameraNode.xScale
        let viewSize = view.bounds.size
        let margin: CGFloat = 1.2 // 20% margin

        let width = viewSize.width * scale * margin
        let height = viewSize.height * scale * margin

        return CGRect(
            x: cameraNode.position.x - width / 2,
            y: cameraNode.position.y - height / 2,
            width: width,
            height: height
        )
    }

    // MARK: - Radius Calculation

    private func radiusForWeight(_ weight: Double) -> CGFloat {
        if weight > 10 {
            return 22
        } else if weight > 3 {
            return 14
        } else {
            return 8
        }
    }

    // MARK: - Edge Rendering

    private func updateEdges() {
        guard let store = graphStore else { return }

        // Recycle all active edges to pool (edges are cheap to redraw)
        for (edgeId, shapeNode) in activeEdges {
            shapeNode.isHidden = true
            shapeNode.removeFromParent()
            edgePool.append(shapeNode)
            activeEdges.removeValue(forKey: edgeId)
        }

        // Draw edges where both endpoints are active (visible)
        for (edgeId, edge) in store.edges {
            guard activeSprites[edge.sourceNodeId] != nil,
                  activeSprites[edge.targetNodeId] != nil,
                  let sourceRecord = store.nodes[edge.sourceNodeId],
                  let targetRecord = store.nodes[edge.targetNodeId] else { continue }

            let sourcePoint = CGPoint(x: CGFloat(sourceRecord.position.x), y: CGFloat(sourceRecord.position.y))
            let targetPoint = CGPoint(x: CGFloat(targetRecord.position.x), y: CGFloat(targetRecord.position.y))

            // Calculate perpendicular offset for control point (organic curves)
            let dx = targetPoint.x - sourcePoint.x
            let dy = targetPoint.y - sourcePoint.y
            let midX = (sourcePoint.x + targetPoint.x) / 2
            let midY = (sourcePoint.y + targetPoint.y) / 2

            // Perpendicular direction, normalized
            let length = sqrt(dx * dx + dy * dy)
            let offset: CGFloat = 15
            let controlPoint: CGPoint
            if length > 0.001 {
                let perpX = -dy / length * offset
                let perpY = dx / length * offset
                controlPoint = CGPoint(x: midX + perpX, y: midY + perpY)
            } else {
                controlPoint = CGPoint(x: midX + offset, y: midY)
            }

            // Build bezier path
            let path = CGMutablePath()
            path.move(to: sourcePoint)
            path.addQuadCurve(to: targetPoint, control: controlPoint)

            // Get or create edge shape
            let shapeNode: SKShapeNode
            if let pooled = edgePool.popLast() {
                shapeNode = pooled
            } else {
                shapeNode = SKShapeNode()
            }

            shapeNode.path = path
            shapeNode.lineWidth = 0.5 + CGFloat(edge.weight) * 0.5

            // Stroke color from source node type at 0.3 opacity
            let sourceColor = Self.nodeColors[sourceRecord.type] ?? .systemGray
            shapeNode.strokeColor = sourceColor.withAlphaComponent(0.3)
            shapeNode.fillColor = .clear
            shapeNode.isHidden = false
            shapeNode.zPosition = -1

            edgeLayer.addChild(shapeNode)
            activeEdges[edgeId] = shapeNode
        }
    }

    // MARK: - Node Hit Testing

    private func nodeAt(_ point: CGPoint) -> GraphNodeSprite? {
        let hitNodes = nodes(at: point)
        for node in hitNodes {
            if let sprite = node as? GraphNodeSprite {
                return sprite
            }
            // Check parent chain in case we hit a child (circle, label, etc.)
            var current = node.parent
            while let parent = current {
                if let sprite = parent as? GraphNodeSprite {
                    return sprite
                }
                current = parent.parent
            }
        }
        return nil
    }

    // MARK: - Mouse Interactions

    override func mouseDown(with event: NSEvent) {
        let location = event.location(in: self)

        if let sprite = nodeAt(location), let nodeId = sprite.recordId {
            // Select node
            selectedNodeId = nodeId
            draggedNodeId = nodeId
            sprite.pulseSelection()
            onNodeSelected?(nodeId)
        } else {
            // Background click — deselect
            selectedNodeId = nil
            draggedNodeId = nil
            onBackgroundClicked?()
        }

        lastMousePosition = location
    }

    override func mouseDragged(with event: NSEvent) {
        let location = event.location(in: self)

        if let draggedId = draggedNodeId {
            // Dragging a node — update sprite position and store
            if let sprite = activeSprites[draggedId] {
                sprite.position = location
            }

            let simPosition = SIMD2<Float>(Float(location.x), Float(location.y))
            graphStore?.updatePosition(draggedId, position: simPosition)

            // Update simulation (fire-and-forget on the actor)
            if let sim = forceSimulation {
                Task {
                    await sim.updateNodePosition(draggedId, position: simPosition)
                }
            }
        } else if let lastPos = lastMousePosition {
            // Pan camera
            let dx = location.x - lastPos.x
            let dy = location.y - lastPos.y
            cameraNode.position.x -= dx
            cameraNode.position.y -= dy
        }

        lastMousePosition = location
    }

    override func mouseUp(with event: NSEvent) {
        draggedNodeId = nil
        lastMousePosition = nil
    }

    override func rightMouseDown(with event: NSEvent) {
        let location = event.location(in: self)

        if let sprite = nodeAt(location), let nodeId = sprite.recordId {
            // Convert to screen coordinates for context menu
            guard let view else { return }
            let windowPoint = event.locationInWindow
            let screenPoint = view.window?.convertPoint(toScreen: windowPoint) ?? windowPoint
            onNodeRightClicked?(nodeId, screenPoint)
        }
    }

    override func mouseMoved(with event: NSEvent) {
        let location = event.location(in: self)

        let sprite = nodeAt(location)
        let newHoveredId = sprite?.recordId

        // Unhover previous
        if let previousId = hoveredNodeId, previousId != newHoveredId {
            activeSprites[previousId]?.hideHoverGlow()
        }

        // Hover new
        if let currentId = newHoveredId, currentId != hoveredNodeId {
            if let hoveredSprite = activeSprites[currentId],
               let record = graphStore?.nodes[currentId] {
                let color = Self.nodeColors[record.type] ?? .systemGray
                hoveredSprite.showHoverGlow(color: color)
            }
        }

        hoveredNodeId = newHoveredId
    }

    override func scrollWheel(with event: NSEvent) {
        let zoomDelta = event.deltaY * 0.03
        let newScale = cameraNode.xScale - zoomDelta
        let clamped = min(max(newScale, 0.05), 5.0)
        cameraNode.setScale(clamped)
    }

    override func magnify(with event: NSEvent) {
        let newScale = cameraNode.xScale - event.magnification
        let clamped = min(max(newScale, 0.05), 5.0)
        cameraNode.setScale(clamped)
    }

    // MARK: - Public API

    /// Animate camera to center on a specific node.
    func centerOnNode(_ nodeId: String) {
        guard let record = graphStore?.nodes[nodeId] else { return }
        let targetPos = CGPoint(x: CGFloat(record.position.x), y: CGFloat(record.position.y))
        let moveAction = SKAction.move(to: targetPos, duration: 0.4)
        moveAction.timingMode = .easeInEaseOut
        cameraNode.run(moveAction)
    }

    /// Reset camera to origin at scale 1.0.
    func resetView() {
        let moveAction = SKAction.move(to: .zero, duration: 0.3)
        let scaleAction = SKAction.scale(to: 1.0, duration: 0.3)
        moveAction.timingMode = .easeInEaseOut
        scaleAction.timingMode = .easeInEaseOut
        cameraNode.run(.group([moveAction, scaleAction]))
    }
}
