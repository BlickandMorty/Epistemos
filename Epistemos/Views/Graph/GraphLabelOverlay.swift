import AppKit
import QuartzCore

/// Transparent NSView overlaid on MTKView. Owns a pool of CATextLayer instances
/// positioned every frame by the Rust engine's on_labels_updated callback.
final class GraphLabelOverlay: NSView {
    private var layerPool: [String: CATextLayer] = [:]
    private var activeUUIDs: Set<String> = []

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.isGeometryFlipped = true  // Match MTKView Y-down coordinate system
    }

    required init?(coder: NSCoder) { fatalError() }

    /// Called every frame from the Rust callback (dispatched to main queue).
    func updateLabels(positions: [(uuid: String, x: CGFloat, y: CGFloat, radius: CGFloat, alpha: Float)]) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        var newActive = Set<String>()

        for pos in positions {
            newActive.insert(pos.uuid)
            let layer = getOrCreateLayer(uuid: pos.uuid)
            layer.position = CGPoint(x: pos.x, y: pos.y + pos.radius + 4)
            layer.opacity = pos.alpha
        }

        // Hide layers not in the current set
        for uuid in activeUUIDs.subtracting(newActive) {
            layerPool[uuid]?.opacity = 0
        }
        activeUUIDs = newActive

        CATransaction.commit()
    }

    /// Rebuild layer pool from scratch (called on data reload).
    func rebuildPool(labels: [(uuid: String, text: String)]) {
        layer?.sublayers?.forEach { $0.removeFromSuperlayer() }
        layerPool.removeAll()
        activeUUIDs.removeAll()

        for (uuid, text) in labels {
            let textLayer = makeTextLayer(text: text)
            textLayer.opacity = 0
            layer?.addSublayer(textLayer)
            layerPool[uuid] = textLayer
        }
    }

    private func getOrCreateLayer(uuid: String) -> CATextLayer {
        if let existing = layerPool[uuid] { return existing }
        let textLayer = makeTextLayer(text: "")
        layer?.addSublayer(textLayer)
        layerPool[uuid] = textLayer
        return textLayer
    }

    private func makeTextLayer(text: String) -> CATextLayer {
        let tl = CATextLayer()
        let truncated = text.count > 20 ? String(text.prefix(20)) + "..." : text
        tl.string = truncated
        tl.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        tl.fontSize = 11
        tl.foregroundColor = NSColor.white.cgColor
        tl.shadowColor = NSColor.black.withAlphaComponent(0.6).cgColor
        tl.shadowOffset = CGSize(width: 0, height: 1)
        tl.shadowRadius = 2
        tl.shadowOpacity = 1
        tl.alignmentMode = .center
        tl.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
        tl.bounds = CGRect(x: 0, y: 0, width: 150, height: 16)
        tl.anchorPoint = CGPoint(x: 0.5, y: 0) // Anchor at top-center (below node)
        return tl
    }
}
