import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - DocumentEditorView
// NSViewRepresentable wrapping a TextKit 2 backed NSTextView for WYSIWYG
// rich text editing. Single continuous scroll, no pagination.
//
// Architecture:
//   NSScrollView
//   +-- NSTextView (TextKit 2)
//        +-- NSTextContentStorage (owns NSAttributedString)
//        +-- NSTextLayoutManager (single container)
//        +-- NSTextContainer (full width, infinite height)

struct DocumentEditorView: NSViewRepresentable {

    @Binding var attributedText: NSAttributedString
    let isDark: Bool
    var theme: EpistemosTheme = .light
    let isEditable: Bool
    let formatState: DocumentFormatState

    private static let verticalInset: CGFloat = 80

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.autohidesScrollers = true

        // TextKit 2 setup
        let contentStorage = NSTextContentStorage()
        let layoutManager = NSTextLayoutManager()
        contentStorage.addTextLayoutManager(layoutManager)

        let container = NSTextContainer()
        container.widthTracksTextView = true
        container.heightTracksTextView = false
        layoutManager.textContainer = container

        // Set initial attributed content
        contentStorage.attributedString = attributedText.length > 0
            ? NSMutableAttributedString(attributedString: attributedText)
            : NSMutableAttributedString(string: "", attributes: defaultAttributes())

        let textView = NSTextView(frame: .zero, textContainer: container)
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.isRichText = true
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 60, height: Self.verticalInset)
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = true
        textView.isGrammarCheckingEnabled = true
        textView.writingToolsBehavior = .default
        textView.delegate = context.coordinator
        textView.allowsImageEditing = true

        // Enable drag & drop for images
        textView.registerForDraggedTypes([.fileURL, .png, .tiff])

        scrollView.documentView = textView
        context.coordinator.textView = textView

        applyTheme(to: textView)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        textView.isEditable = isEditable
        applyTheme(to: textView)

        // Sync attributed text if changed externally (e.g., DOCX import)
        if context.coordinator.isExternalUpdate {
            context.coordinator.isExternalUpdate = false
            if let contentStorage = textView.textLayoutManager?.textContentManager as? NSTextContentStorage {
                contentStorage.attributedString = NSMutableAttributedString(attributedString: attributedText)
            }
        }
    }

    private func applyTheme(to textView: NSTextView) {
        textView.insertionPointColor = isDark ? .white : .black
    }

    private func defaultAttributes() -> [NSAttributedString.Key: Any] {
        let font = NSFont(name: "New York", size: 14)
            ?? NSFont(name: "Palatino", size: 14)
            ?? NSFont.systemFont(ofSize: 14)
        let paraStyle = NSMutableParagraphStyle()
        paraStyle.lineSpacing = 4
        return [
            .font: font,
            .foregroundColor: isDark ? NSColor.white : NSColor.black,
            .paragraphStyle: paraStyle,
        ]
    }

    // MARK: - Coordinator

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: DocumentEditorView
        weak var textView: NSTextView?
        var isExternalUpdate = false
        private var syncTask: Task<Void, Never>?

        init(parent: DocumentEditorView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            guard !tv.hasMarkedText() else { return }

            // Debounced sync to parent binding
            syncTask?.cancel()
            syncTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(500))
                guard let self, !Task.isCancelled else { return }
                guard let storage = self.textView?.textStorage else { return }
                self.parent.attributedText = NSAttributedString(attributedString: storage)
            }
        }

        // MARK: - Typing Attributes

        func textView(_ textView: NSTextView, shouldChangeTypingAttributes oldAttrs: [String: Any],
                       toAttributes newAttrs: [NSAttributedString.Key: Any]) -> [NSAttributedString.Key: Any] {
            // Apply format state overrides for new typing
            var attrs = newAttrs
            let state = parent.formatState

            var font = attrs[.font] as? NSFont ?? NSFont.systemFont(ofSize: 14)
            let manager = NSFontManager.shared

            if state.isBold {
                font = manager.convert(font, toHaveTrait: .boldFontMask)
            }
            if state.isItalic {
                font = manager.convert(font, toHaveTrait: .italicFontMask)
            }
            attrs[.font] = font

            if state.isUnderline {
                attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue
            }

            return attrs
        }
    }
}

// MARK: - DOCX Import/Export

extension DocumentEditorView {

    /// Reads a .docx file and returns an NSAttributedString.
    static func importDOCX(from url: URL) -> NSAttributedString? {
        var attrs: NSDictionary?
        guard let attrStr = try? NSAttributedString(
            url: url,
            options: [.documentType: NSAttributedString.DocumentType.officeOpenXML],
            documentAttributes: &attrs
        ) else { return nil }
        return attrStr
    }

    /// Exports the given NSAttributedString to a .docx file.
    static func exportDOCX(_ attributedString: NSAttributedString, to url: URL) throws {
        let data = try attributedString.data(
            from: NSRange(location: 0, length: attributedString.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.officeOpenXML]
        )
        try data.write(to: url)
    }
}
