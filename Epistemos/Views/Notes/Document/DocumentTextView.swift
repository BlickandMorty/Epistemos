import AppKit

// MARK: - DocumentTextView
// NSTextView subclass backed by TextKit 2 (NSTextLayoutManager).
// Continuous scroll, single container, viewport-based rendering.
// Used as the primary writing surface for document mode.

final class DocumentTextView: NSTextView {

    // MARK: - Factory

    /// Create a TextKit 2-backed text view with a single container in a scroll view.
    static func makeTextKit2() -> (NSScrollView, DocumentTextView) {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        let contentStorage = NSTextContentStorage()
        let layoutManager = NSTextLayoutManager()
        contentStorage.addTextLayoutManager(layoutManager)

        let container = NSTextContainer()
        container.widthTracksTextView = true
        container.heightTracksTextView = false
        layoutManager.textContainer = container

        let tv = DocumentTextView(frame: .zero, textContainer: container)
        tv.isEditable = true
        tv.isSelectable = true
        tv.isRichText = true
        tv.allowsUndo = true
        tv.isAutomaticSpellingCorrectionEnabled = true
        tv.isGrammarCheckingEnabled = true
        tv.usesFindBar = true
        tv.isIncrementalSearchingEnabled = true
        tv.drawsBackground = true
        tv.textContainerInset = NSSize(width: 60, height: 40)
        tv.writingToolsBehavior = .default

        let defaultParagraph = NSMutableParagraphStyle()
        defaultParagraph.lineSpacing = 6
        defaultParagraph.paragraphSpacing = 8
        tv.defaultParagraphStyle = defaultParagraph
        tv.typingAttributes = [
            .font: NSFont(name: "New York", size: 16) ?? .systemFont(ofSize: 16),
            .foregroundColor: NSColor.textColor,
            .paragraphStyle: defaultParagraph
        ]

        scrollView.documentView = tv
        return (scrollView, tv)
    }

    // MARK: - Image Drag-Drop

    override func readSelection(from pboard: NSPasteboard, type: NSPasteboard.PasteboardType) -> Bool {
        if pboard.canReadObject(forClasses: [NSImage.self]) {
            if let images = pboard.readObjects(forClasses: [NSImage.self]) as? [NSImage],
               let image = images.first {
                let attachment = NSTextAttachment()
                let cell = NSTextAttachmentCell(imageCell: image)
                attachment.attachmentCell = cell
                let attrStr = NSAttributedString(attachment: attachment)
                insertText(attrStr, replacementRange: selectedRange())
                return true
            }
        }
        return super.readSelection(from: pboard, type: type)
    }
}
