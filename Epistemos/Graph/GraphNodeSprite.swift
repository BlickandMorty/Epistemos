import SpriteKit

// MARK: - GraphNodeSprite
// A reusable SKNode subclass representing one graph node. Pooled by KnowledgeGraphScene.
// Contains a circle shape, icon, label, glow effect node, and optional evidence grade ring.

final class GraphNodeSprite: SKNode {

    // MARK: - Child Nodes

    let circle: SKShapeNode
    let iconSprite: SKSpriteNode
    let labelNode: SKLabelNode
    let glowNode: SKEffectNode
    let gradeRing: SKShapeNode

    // MARK: - State

    var recordId: String?

    /// Tracks whether this sprite was already animated in, to avoid repeating the entrance animation
    /// when LOD or position updates re-configure the sprite within the same activation cycle.
    private var hasAnimatedIn: Bool = false

    /// Cached LOD band to avoid redundant property sets every frame.
    private var currentLODBand: Int = -1

    /// Baseline glow alpha from research stage (hover fades back to this, not zero).
    private var researchGlowAlpha: CGFloat = 0

    /// Whether this node has an evidence grade ring configured.
    private var hasGradeRing: Bool = false

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

        // Glow: blur effect for hover/selection/research-stage
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

        // Evidence grade ring: thin ring slightly larger than the circle
        gradeRing = SKShapeNode(circleOfRadius: 12)
        gradeRing.fillColor = .clear
        gradeRing.strokeColor = .systemYellow
        gradeRing.lineWidth = 1.5
        gradeRing.alpha = 0
        gradeRing.isHidden = true
        gradeRing.zPosition = -0.5

        super.init()

        addChild(glowNode)
        addChild(gradeRing)
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

        // Evidence grade ring
        configureGradeRing(metadata: record.metadata, radius: radius)

        // Research stage glow
        configureResearchGlow(metadata: record.metadata, color: color)

        // Animate entrance (scale from zero + fade)
        if !hasAnimatedIn {
            hasAnimatedIn = true
            setScale(0)
            alpha = 0
            isHidden = false
            run(SKAction.group([
                SKAction.scale(to: 1.0, duration: 0.3),
                SKAction.fadeIn(withDuration: 0.2)
            ]))
        } else {
            isHidden = false
            alpha = 1
        }
    }

    // MARK: - Evidence Grade Ring

    /// Show or hide the evidence grade ring based on metadata.
    private func configureGradeRing(metadata: GraphNodeMetadata, radius: CGFloat) {
        guard let grade = metadata.evidenceGrade else {
            gradeRing.isHidden = true
            gradeRing.alpha = 0
            return
        }

        // Scale the ring to match the node radius (ring is base radius 12, so offset = +2pt from circle)
        let ringScale = (radius + 2.0) / 12.0
        gradeRing.setScale(ringScale)

        switch grade {
        case "A":
            gradeRing.strokeColor = NSColor.systemYellow
            gradeRing.alpha = 0.8
            gradeRing.isHidden = false
            hasGradeRing = true
        case "B":
            gradeRing.strokeColor = NSColor.lightGray
            gradeRing.alpha = 0.6
            gradeRing.isHidden = false
            hasGradeRing = true
        default:
            gradeRing.isHidden = true
            gradeRing.alpha = 0
            hasGradeRing = false
        }
    }

    // MARK: - Research Stage Glow

    /// Enhance glow for mature research stages (4+).
    private func configureResearchGlow(metadata: GraphNodeMetadata, color: NSColor) {
        guard let stage = metadata.researchStage, stage >= 4 else {
            // Don't touch glowNode alpha here — it may be controlled by hover.
            // Only reset if we're doing initial config (no hover active).
            return
        }

        // Set glow color to a warm version of the node color
        if let glowCircle = glowNode.children.first as? SKShapeNode {
            glowCircle.fillColor = color
        }

        switch stage {
        case 4:
            researchGlowAlpha = 0.3
            glowNode.alpha = 0.3
        case 5:
            researchGlowAlpha = 0.5
            glowNode.alpha = 0.5
        default:
            break
        }
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
        labelNode.isHidden = false
        iconSprite.texture = nil
        iconSprite.isHidden = false
        gradeRing.isHidden = true
        gradeRing.alpha = 0
        hasGradeRing = false
        hasAnimatedIn = false
        currentLODBand = -1
        researchGlowAlpha = 0
        setScale(1.0)
    }

    /// Animate out then recycle. The completion handler is called after the animation
    /// finishes, allowing the caller to return this sprite to the pool.
    func animateOutThenRecycle(completion: @escaping () -> Void) {
        run(SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 0, duration: 0.3),
                SKAction.fadeOut(withDuration: 0.3)
            ]),
            SKAction.run { [weak self] in
                self?.recycle()
                completion()
            }
        ]))
    }

    // MARK: - LOD Appearance

    /// Apply level-of-detail settings based on camera zoom scale.
    /// - Parameters:
    ///   - scale: Current camera xScale (higher = more zoomed out)
    ///   - radius: The computed radius for this node's weight
    ///   - weight: The node's weight (for hub-node label decisions)
    func applyLOD(scale: CGFloat, radius: CGFloat, weight: Double) {
        // Determine LOD band (0=dots, 1=medium, 2=normal, 3=closeUp)
        let band: Int
        if scale > 2.0 { band = 0 }
        else if scale > 1.0 { band = 1 }
        else if scale > 0.5 { band = 2 }
        else { band = 3 }

        // Skip redundant updates if band hasn't changed
        guard band != currentLODBand else { return }
        currentLODBand = band

        switch band {
        case 0:
            // Zoomed way out — colored dots only
            iconSprite.isHidden = true
            labelNode.isHidden = true
            circle.setScale(3.0 / 10.0)
            gradeRing.isHidden = true
        case 1:
            // Medium zoom out — circles with color, labels on hub nodes only
            iconSprite.isHidden = true
            circle.setScale(radius / 10.0)
            labelNode.isHidden = weight <= 5
            gradeRing.isHidden = !hasGradeRing
        default:
            // Normal + close-up — full nodes with icons + labels
            iconSprite.isHidden = false
            circle.setScale(radius / 10.0)
            labelNode.isHidden = false
            gradeRing.isHidden = !hasGradeRing
        }
    }

    // MARK: - Glow Effects

    /// Animate glow in over 0.2s.
    func showHoverGlow(color: NSColor) {
        if let glowCircle = glowNode.children.first as? SKShapeNode {
            glowCircle.fillColor = color
        }
        glowNode.run(.fadeAlpha(to: 0.6, duration: 0.2))
    }

    /// Animate glow out over 0.15s, returning to research-stage baseline if applicable.
    func hideHoverGlow() {
        glowNode.run(.fadeAlpha(to: researchGlowAlpha, duration: 0.15))
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
