import SpriteKit
import SwiftUI

// MARK: - GraphSpriteView
// NSViewRepresentable wrapping SKView + KnowledgeGraphScene.
// Bridges the SpriteKit force-directed graph into a SwiftUI layout.

struct GraphSpriteView: NSViewRepresentable {
    let graphState: GraphState
    var onNodeRightClicked: ((String, CGPoint) -> Void)?

    func makeNSView(context: Context) -> SKView {
        let skView = SKView()
        skView.allowsTransparency = true
        skView.ignoresSiblingOrder = true

        let scene = KnowledgeGraphScene(size: CGSize(width: 800, height: 600))
        scene.scaleMode = .resizeFill
        scene.backgroundColor = .clear
        scene.graphStore = graphState.store
        scene.filterEngine = graphState.filter
        scene.forceSimulation = graphState.simulation
        scene.graphState = graphState

        scene.onNodeSelected = { id in
            Task { @MainActor in graphState.selectNode(id) }
        }
        scene.onBackgroundClicked = {
            Task { @MainActor in graphState.selectNode(nil) }
        }
        scene.onNodeRightClicked = { [onNodeRightClicked] nodeId, screenPoint in
            onNodeRightClicked?(nodeId, screenPoint)
        }

        context.coordinator.scene = scene
        skView.presentScene(scene)
        return skView
    }

    func updateNSView(_ skView: SKView, context: Context) {
        // Update the right-click callback in case it changed
        context.coordinator.scene?.onNodeRightClicked = { [onNodeRightClicked] nodeId, screenPoint in
            onNodeRightClicked?(nodeId, screenPoint)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var scene: KnowledgeGraphScene?
    }
}
