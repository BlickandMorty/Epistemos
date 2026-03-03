import AppKit
import SwiftData

// MARK: - TransclusionOverlayManager
// Manages floating EditableTransclusionView overlays positioned over ((block-ref)) ranges.
// Each overlay is an editable text view showing the referenced block's content inline.
// Edits fire onBlockEdit which routes through BTK as UpdateBlock ops.
//
// Lifecycle:
//   - Created once per editor (stored on Coordinator)
//   - Repositions overlays on scroll (via clip view bounds change notification)
//   - Refreshes content when text changes (called from textDidChange)
//   - Only renders overlays for visible transclusions — O(visible), not O(document)

@MainActor
final class TransclusionOverlayManager {

    private weak var textView: NSTextView?
    private var overlays: [String: EditableTransclusionView] = [:] // blockId -> overlay
    private var modelContext: ModelContext?

    /// Callback when a transclusion is edited. (blockId, newContent)
    var onBlockEdit: ((String, String) -> Void)?

    /// Maximum transclusion depth to prevent circular references.
    private static let maxDepth = 3

    init(textView: NSTextView) {
        self.textView = textView
    }

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Refresh

    /// Scan visible text for ((ref)) markers and position overlays.
    /// Called after text changes and on scroll.
    func refresh() {
        guard let textView, let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer,
              let storage = textView.textStorage
        else { return }

        let visibleRect = textView.visibleRect
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)

        // Find all ((ref)) markers with EpistemosBlockRef attribute in visible range.
        var activeBlockIds = Set<String>()

        storage.enumerateAttribute(
            NSAttributedString.Key("EpistemosBlockRef"),
            in: charRange,
            options: []
        ) { value, range, _ in
            guard let blockId = value as? String else { return }
            activeBlockIds.insert(blockId)

            // Get the bounding rect for this range.
            let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            let lineRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)

            // Convert to text view coordinates.
            let origin = textView.textContainerOrigin
            let overlayRect = NSRect(
                x: origin.x + lineRect.minX,
                y: origin.y + lineRect.maxY + 2, // Below the ref marker
                width: max(0, min(lineRect.width + 100, textView.bounds.width - origin.x * 2)),
                height: 0 // Will be sized by content
            )

            // Create or update overlay.
            let overlayHeight: CGFloat = 32
            if let existing = overlays[blockId] {
                existing.frame = NSRect(
                    x: overlayRect.origin.x,
                    y: overlayRect.origin.y,
                    width: overlayRect.width,
                    height: overlayHeight
                )
            } else {
                let resolved = resolveBlock(blockId)
                let overlay = EditableTransclusionView(
                    blockId: blockId,
                    sourcePageId: resolved?.pageId ?? ""
                )
                overlay.frame = NSRect(
                    x: overlayRect.origin.x,
                    y: overlayRect.origin.y,
                    width: overlayRect.width,
                    height: overlayHeight
                )
                if let resolved {
                    overlay.setContent(resolved.content)
                    if let title = resolvePageTitle(resolved.pageId) {
                        overlay.setProvenance(pageTitle: title)
                    }
                } else {
                    overlay.setMissing()
                }
                overlay.onEdit = { [weak self] blockId, newContent in
                    self?.onBlockEdit?(blockId, newContent)
                }
                textView.addSubview(overlay)
                overlays[blockId] = overlay
            }
        }

        // Remove overlays for refs no longer visible.
        let toRemove = overlays.keys.filter { !activeBlockIds.contains($0) }
        for blockId in toRemove {
            overlays[blockId]?.removeFromSuperview()
            overlays.removeValue(forKey: blockId)
        }
    }

    /// Remove all overlays (called on page switch or dealloc).
    func removeAll() {
        for (_, overlay) in overlays {
            overlay.removeFromSuperview()
        }
        overlays.removeAll()
    }

    // MARK: - Block Resolution

    private struct ResolvedBlock {
        let content: String
        let pageId: String
    }

    private func resolveBlock(_ blockId: String, depth: Int = 0) -> ResolvedBlock? {
        guard depth < Self.maxDepth else { return ResolvedBlock(content: "[Circular reference]", pageId: "") }
        guard let modelContext else { return nil }

        let descriptor = FetchDescriptor<SDBlock>(
            predicate: #Predicate<SDBlock> { $0.id == blockId }
        )
        guard let block = try? modelContext.fetch(descriptor).first else { return nil }
        return ResolvedBlock(content: block.content, pageId: block.pageId)
    }

    private func resolvePageTitle(_ pageId: String) -> String? {
        guard let modelContext, !pageId.isEmpty else { return nil }

        let descriptor = FetchDescriptor<SDPage>(
            predicate: #Predicate<SDPage> { $0.id == pageId }
        )
        return try? modelContext.fetch(descriptor).first?.title
    }
}
