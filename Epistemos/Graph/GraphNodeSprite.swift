import SpriteKit

// MARK: - GraphNodeSprite
// A reusable SKNode subclass representing one graph node. Pooled by KnowledgeGraphScene.
// Contains a circle shape, icon, label, and glow effect node.

final class GraphNodeSprite: SKNode {

    // MARK: - Child Nodes

    let circle: SKShapeNode
    let iconSprite: SKSpriteNode
    let labelNode: SKLabelNode
    let glowNode: SKEffectNode

    // MARK: - State

    var recordId: String?

    // MARK: - Init

    override init() {
        // Circle: base radius 10, scaled per node weight later
        circle = SKShapeNode(circleOfRadius: 10)
        circle.strokeColor = .clear
        circle.fillColor = .systemBlue
        circle.lineWidth = 0

        // Icon: SF Symbol centered in circle
        iconSprite = SKSpriteNode()
        iconSprite.size = CGSize(width: 12, height: 12)
        iconSprite.position = .zero

        // Label: name below circle
        labelNode = SKLabelNode(fontNamed: "SF Pro Text")
        labelNode.fontSize = 10
        labelNode.fontColor = .labelColor
        labelNode.verticalAlignmentMode = .top
        labelNode.horizontalAlignmentMode = .center
        labelNode.position = CGPoint(x: 0, y: -14)

        // Glow: blur effect for hover/selection
        glowNode = SKEffectNode()
        let glowCircle = SKShapeNode(circleOfRadius: 14)
        glowCircle.fillColor = .white
        glowCircle.strokeColor = .clear
        glowNode.addChild(glowCircle)
        glowNode.filter = CIFilter(name: "CIGaussianBlur", parameters: ["inputRadius": 8.0])
        glowNode.shouldEnableEffects = true
        glowNode.shouldRasterize = true
        glowNode.alpha = 0
        glowNode.zPosition = -1

        super.init()

        addChild(glowNode)
        addChild(circle)
        circle.addChild(iconSprite)
        addChild(labelNode)

        isHidden = true
        alpha = 0
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Configuration

    /// Set up the sprite for a specific graph node record.
    func configure(record: GraphNodeRecord, color: NSColor, radius: CGFloat, showLabel: Bool) {
        recordId = record.id

        // Position from record
        position = CGPoint(x: CGFloat(record.position.x), y: CGFloat(record.position.y))

        // Circle color and scale
        circle.fillColor = color
        circle.setScale(radius / 10.0)

        // Icon from SF Symbol
        let config = NSImage.SymbolConfiguration(pointSize: 10, weight: .medium)
        if let symbolImage = NSImage(systemSymbolName: record.type.icon, accessibilityDescription: nil)?
            .withSymbolConfiguration(config) {
            let texture = SKTexture(image: symbolImage)
            iconSprite.texture = texture
            iconSprite.size = CGSize(width: 12, height: 12)
            iconSprite.color = .white
            iconSprite.colorBlendFactor = 1.0
        }

        // Label
        labelNode.text = record.label
        labelNode.isHidden = !showLabel
        labelNode.position = CGPoint(x: 0, y: -radius - 4)

        // Show
        isHidden = false
        alpha = 1
    }

    // MARK: - Recycling

    /// Clear state, hide, and return to pool.
    func recycle() {
        recordId = nil
        isHidden = true
        alpha = 0
        removeAllActions()
        glowNode.alpha = 0
        circle.setScale(1.0)
        labelNode.text = nil
        iconSprite.texture = nil
    }

    // MARK: - Glow Effects

    /// Animate glow in over 0.2s.
    func showHoverGlow(color: NSColor) {
        if let glowCircle = glowNode.children.first as? SKShapeNode {
            glowCircle.fillColor = color
        }
        glowNode.run(.fadeAlpha(to: 0.6, duration: 0.2))
    }

    /// Animate glow out over 0.15s.
    func hideHoverGlow() {
        glowNode.run(.fadeAlpha(to: 0, duration: 0.15))
    }

    // MARK: - Selection Animation

    /// Pulse: scale up to 1.15 then back to 1.0.
    func pulseSelection() {
        let scaleUp = SKAction.scale(to: 1.15, duration: 0.1)
        let scaleDown = SKAction.scale(to: 1.0, duration: 0.1)
        scaleUp.timingMode = .easeOut
        scaleDown.timingMode = .easeIn
        run(.sequence([scaleUp, scaleDown]))
    }
}
