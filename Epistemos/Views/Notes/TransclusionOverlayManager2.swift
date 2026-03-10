import AppKit
import SwiftData

// MARK: - TransclusionOverlayManager2
// TextKit 2 port of TransclusionOverlayManager.
// Manages floating EditableTransclusionView overlays positioned over ((block-ref)) ranges.
// Each overlay is an editable text view showing the referenced block's content inline.
// Edits fire onBlockEdit which routes through BTK as UpdateBlock ops.
//
// Geometry: Uses NSTextLayoutManager.enumerateTextLayoutFragments(from:options:)
// + fragment.layoutFragmentFrame instead of TK1's glyphRange(forBoundingRect:) +
// boundingRect(forGlyphRange:).
//
// Lifecycle:
//   - Created once per editor (stored on Coordinator2)
//   - Repositions overlays on scroll (via clip view bounds change notification)
//   - Refreshes content when text changes (called from textDidChange)
//   - Only renders overlays for visible transclusions — O(visible), not O(document)

@MainActor
final class TransclusionOverlayManager2 {

    private weak var textView: NSTextView?
    /// Keyed by "\(blockId)@\(charOffset)" so duplicate refs to the same block
    /// each get their own overlay.
    private var overlays: [String: EditableTransclusionView] = [:]
    private var modelContext: ModelContext?

    /// Callback when a transclusion is edited. (blockId, newContent)
    var onBlockEdit: ((String, String) -> Void)?

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
        guard let textView,
              let tlm = textView.textLayoutManager,
              let contentStorage = tlm.textContentManager as? NSTextContentStorage,
              let storage = textView.textStorage
        else { return }

        guard storage.length > 0 else {
            removeAll()
            return
        }

        let visibleRect = textView.visibleRect
        let origin = textView.textContainerOrigin
        let docStart = contentStorage.documentRange.location

        // Jump directly to the first visible fragment via point lookup — O(log n).
        // This matches TK1's glyphRange(forBoundingRect:) which also jumped to the viewport.
        let topPoint = CGPoint(x: 0, y: max(visibleRect.minY - origin.y, 0))
        guard let startFragment = tlm.textLayoutFragment(for: topPoint),
              let startLoc = startFragment.textElement?.elementRange?.location
        else {
            removeAll()
            return
        }

        // Enumerate forward from the first visible fragment to compute the visible char range.
        var visibleStart = 0
        var visibleEnd = 0
        var foundStart = false

        tlm.enumerateTextLayoutFragments(
            from: startLoc,
            options: [.ensuresLayout, .estimatesSize]
        ) { fragment in
            let fragFrame = fragment.layoutFragmentFrame
            let viewY = origin.y + fragFrame.origin.y

            // Past visible area — stop
            if viewY > visibleRect.maxY { return false }

            if let elemRange = fragment.textElement?.elementRange {
                let start = contentStorage.offset(from: docStart, to: elemRange.location)
                let end = contentStorage.offset(from: docStart, to: elemRange.endLocation)
                if !foundStart {
                    visibleStart = start
                    foundStart = true
                }
                visibleEnd = max(visibleEnd, end)
            }

            return true
        }

        guard foundStart, visibleEnd > visibleStart else {
            removeAll()
            return
        }

        let charRange = NSRange(
            location: visibleStart,
            length: min(visibleEnd - visibleStart, storage.length - visibleStart)
        )

        // Find all ((ref)) markers via .link attribute with "blockref://" prefix.
        // Both TK1 (MarkdownTextStorage) and TK2 (MarkdownContentStorage) set
        // .link: "blockref://\(blockId)" on block reference content ranges.
        var activeKeys = Set<String>()
        let blockrefPrefix = "blockref://"

        storage.enumerateAttribute(
            .link,
            in: charRange,
            options: []
        ) { value, range, _ in
            let urlString: String
            if let str = value as? String { urlString = str }
            else if let url = value as? URL { urlString = url.absoluteString }
            else { return }
            guard urlString.hasPrefix(blockrefPrefix) else { return }
            let blockId = String(urlString.dropFirst(blockrefPrefix.count))
            guard !blockId.isEmpty else { return }
            let overlayKey = "\(blockId)@\(range.location)"
            activeKeys.insert(overlayKey)

            // Compute precise bounding rect for the ref's character range.
            let refCharIndex = range.location
            guard let refLoc = contentStorage.location(docStart, offsetBy: refCharIndex),
                  let fragment = tlm.textLayoutFragment(for: refLoc)
            else { return }

            let fragFrame = fragment.layoutFragmentFrame

            // Walk line fragments to find the one(s) containing this ref range,
            // computing a precise bounding rect like TK1's boundingRect(forGlyphRange:).
            let elemStart: Int
            if let elemRange = fragment.textElement?.elementRange {
                elemStart = contentStorage.offset(from: docStart, to: elemRange.location)
            } else {
                elemStart = refCharIndex
            }
            let refStartInPara = refCharIndex - elemStart
            let refEndInPara = refStartInPara + range.length

            var refMinX = fragFrame.maxX
            var refMaxX = fragFrame.minX
            var refMinY = fragFrame.maxY
            var refMaxY = fragFrame.minY

            for lineFrag in fragment.textLineFragments {
                let lineCharStart = lineFrag.characterRange.location
                let lineCharEnd = lineCharStart + lineFrag.characterRange.length
                guard refStartInPara < lineCharEnd, refEndInPara > lineCharStart else { continue }

                // Clamp to the intersection within this line fragment
                let clampStart = max(refStartInPara, lineCharStart) - lineCharStart
                let clampEnd = min(refEndInPara, lineCharEnd) - lineCharStart

                let startX = lineFrag.locationForCharacter(at: clampStart).x
                let endX = lineFrag.locationForCharacter(at: clampEnd).x

                let lineOrigin = lineFrag.typographicBounds.origin
                let lineHeight = lineFrag.typographicBounds.height

                refMinX = min(refMinX, fragFrame.minX + startX)
                refMaxX = max(refMaxX, fragFrame.minX + endX)
                refMinY = min(refMinY, fragFrame.minY + lineOrigin.y)
                refMaxY = max(refMaxY, fragFrame.minY + lineOrigin.y + lineHeight)
            }

            // Fallback to full fragment if line-fragment walk produced no result
            if refMinX >= refMaxX || refMinY >= refMaxY {
                refMinX = fragFrame.minX
                refMaxX = fragFrame.maxX
                refMinY = fragFrame.minY
                refMaxY = fragFrame.maxY
            }

            let overlayRect = NSRect(
                x: origin.x + refMinX,
                y: origin.y + refMaxY + 2,
                width: max(0, min(refMaxX - refMinX + 100, textView.bounds.width - origin.x * 2)),
                height: 0
            )

            let overlayHeight: CGFloat = 32
            if let existing = overlays[overlayKey] {
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
                overlays[overlayKey] = overlay
            }
        }

        // Remove overlays for refs no longer visible.
        let toRemove = overlays.keys.filter { !activeKeys.contains($0) }
        for key in toRemove {
            overlays[key]?.removeFromSuperview()
            overlays.removeValue(forKey: key)
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
