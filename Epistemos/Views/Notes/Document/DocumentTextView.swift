import AppKit

// MARK: - DocumentTextView
// NSTextView subclass backed by TextKit 2 (NSTextLayoutManager).
// Continuous scroll, single container, viewport-based rendering.
// Used as the primary writing surface for document mode.

final class DocumentTextView: NSTextView {

    func applyTheme(_ theme: EpistemosTheme) {
        let foreground = NSColor(theme.foreground)
        backgroundColor = NSColor(theme.background)
        insertionPointColor = foreground
        textColor = foreground

        let paragraph =
            ((typingAttributes[.paragraphStyle] as? NSParagraphStyle)?.mutableCopy()
                as? NSMutableParagraphStyle)
            ?? ((defaultParagraphStyle?.mutableCopy() as? NSMutableParagraphStyle)
                ?? NSMutableParagraphStyle())
        let font = (typingAttributes[.font] as? NSFont)
            ?? font
            ?? NSFont(name: "New York", size: 16)
            ?? .systemFont(ofSize: 16)

        defaultParagraphStyle = paragraph
        typingAttributes = [
            .font: font,
            .foregroundColor: foreground,
            .paragraphStyle: paragraph
        ]
    }

    func rethemeContent(to theme: EpistemosTheme) {
        guard let textStorage else { return }
        let fullRange = NSRange(location: 0, length: textStorage.length)
        guard fullRange.length > 0 else { return }

        let foreground = NSColor(theme.foreground)
        textStorage.beginEditing()
        textStorage.enumerateAttribute(.foregroundColor, in: fullRange) { value, range, _ in
            guard Self.shouldRethemeForeground(value as? NSColor) else { return }
            textStorage.addAttribute(.foregroundColor, value: foreground, range: range)
        }
        textStorage.endEditing()
    }

    func toggleBold() {
        toggleFontTrait(.boldFontMask)
    }

    func toggleItalic() {
        toggleFontTrait(.italicFontMask)
    }

    func toggleUnderline() {
        toggleIntegerAttribute(.underlineStyle, activeValue: NSUnderlineStyle.single.rawValue)
    }

    func toggleStrikethrough() {
        toggleIntegerAttribute(.strikethroughStyle, activeValue: NSUnderlineStyle.single.rawValue)
    }

    func setParagraphAlignment(_ alignment: NSTextAlignment) {
        guard let textStorage else { return }
        let selection = selectedRange()
        let paragraphRange = (string as NSString).paragraphRange(for: selection)

        textStorage.beginEditing()
        textStorage.enumerateAttribute(.paragraphStyle, in: paragraphRange) { value, range, _ in
            let style =
                ((value as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle)
                ?? ((defaultParagraphStyle?.mutableCopy() as? NSMutableParagraphStyle)
                    ?? NSMutableParagraphStyle())
            style.alignment = alignment
            textStorage.addAttribute(.paragraphStyle, value: style, range: range)
        }
        textStorage.endEditing()

        let typingStyle =
            ((typingAttributes[.paragraphStyle] as? NSParagraphStyle)?.mutableCopy()
                as? NSMutableParagraphStyle)
            ?? ((defaultParagraphStyle?.mutableCopy() as? NSMutableParagraphStyle)
                ?? NSMutableParagraphStyle())
        typingStyle.alignment = alignment
        defaultParagraphStyle = typingStyle
        typingAttributes[.paragraphStyle] = typingStyle
    }

    // MARK: - Factory

    /// Create a TextKit 2-backed text view with a single container in a scroll view.
    static func makeTextKit2() -> (NSScrollView, DocumentTextView) {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false

        let tv = DocumentTextView(usingTextLayoutManager: true)
        tv.frame = NSRect(x: 0, y: 0, width: 700, height: 1000)
        tv.minSize = .zero
        tv.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        tv.isHorizontallyResizable = false
        tv.isVerticallyResizable = true
        tv.autoresizingMask = [.width]
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
        tv.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        tv.textContainer?.widthTracksTextView = true
        tv.textContainer?.lineFragmentPadding = 0
        tv.writingToolsBehavior = .default

        let defaultParagraph = NSMutableParagraphStyle()
        defaultParagraph.lineSpacing = 6
        defaultParagraph.paragraphSpacing = 8
        tv.defaultParagraphStyle = defaultParagraph
        tv.applyTheme(.light)

        scrollView.documentView = tv
        DispatchQueue.main.async {
            tv.window?.makeFirstResponder(tv)
        }
        return (scrollView, tv)
    }

    private func toggleFontTrait(_ trait: NSFontTraitMask) {
        guard let textStorage else { return }
        let selection = selectedRange()
        let shouldEnable = !selectionHasFontTrait(selection, trait: trait)

        if selection.length == 0 {
            typingAttributes[.font] = convertFont(resolvedTypingFont(), trait: trait, enable: shouldEnable)
            return
        }

        textStorage.beginEditing()
        textStorage.enumerateAttribute(.font, in: selection) { value, range, _ in
            let currentFont = (value as? NSFont) ?? self.resolvedTypingFont()
            let updatedFont = self.convertFont(currentFont, trait: trait, enable: shouldEnable)
            textStorage.addAttribute(.font, value: updatedFont, range: range)
        }
        textStorage.endEditing()
    }

    private func toggleIntegerAttribute(_ key: NSAttributedString.Key, activeValue: Int) {
        guard let textStorage else { return }
        let selection = selectedRange()
        let shouldEnable = !selectionHasIntegerAttribute(selection, key: key, activeValue: activeValue)

        if selection.length == 0 {
            if shouldEnable {
                typingAttributes[key] = activeValue
            } else {
                typingAttributes.removeValue(forKey: key)
            }
            return
        }

        textStorage.beginEditing()
        if shouldEnable {
            textStorage.addAttribute(key, value: activeValue, range: selection)
        } else {
            textStorage.removeAttribute(key, range: selection)
        }
        textStorage.endEditing()
    }

    private func selectionHasFontTrait(_ selection: NSRange, trait: NSFontTraitMask) -> Bool {
        if selection.length == 0 {
            return resolvedTypingFont().fontDescriptor.symbolicTraits.contains(symbolicTrait(for: trait))
        }

        guard let textStorage else { return false }
        var hasTrait = true
        textStorage.enumerateAttribute(.font, in: selection) { value, _, stop in
            let font = (value as? NSFont) ?? self.resolvedTypingFont()
            if !font.fontDescriptor.symbolicTraits.contains(self.symbolicTrait(for: trait)) {
                hasTrait = false
                stop.pointee = true
            }
        }
        return hasTrait
    }

    private func selectionHasIntegerAttribute(
        _ selection: NSRange,
        key: NSAttributedString.Key,
        activeValue: Int
    ) -> Bool {
        if selection.length == 0 {
            return (typingAttributes[key] as? Int) == activeValue
        }

        guard let textStorage else { return false }
        var isActive = true
        textStorage.enumerateAttribute(key, in: selection) { value, _, stop in
            if (value as? Int) != activeValue {
                isActive = false
                stop.pointee = true
            }
        }
        return isActive
    }

    private func resolvedTypingFont() -> NSFont {
        (typingAttributes[.font] as? NSFont)
            ?? font
            ?? NSFont(name: "New York", size: 16)
            ?? .systemFont(ofSize: 16)
    }

    private func convertFont(_ font: NSFont, trait: NSFontTraitMask, enable: Bool) -> NSFont {
        let manager = NSFontManager.shared
        let converted = enable
            ? manager.convert(font, toHaveTrait: trait)
            : manager.convert(font, toNotHaveTrait: trait)
        return converted.pointSize > 0 ? converted : font
    }

    private func symbolicTrait(for trait: NSFontTraitMask) -> NSFontDescriptor.SymbolicTraits {
        switch trait {
        case .boldFontMask:
            return .bold
        case .italicFontMask:
            return .italic
        default:
            return []
        }
    }

    private static func shouldRethemeForeground(_ color: NSColor?) -> Bool {
        guard let color else { return true }

        let candidates = [
            NSColor.textColor,
            NSColor.labelColor,
            .black,
            .white,
            .darkGray,
            .lightGray
        ] + EpistemosTheme.allCases.map { NSColor($0.foreground) }

        return candidates.contains { candidate in
            color.isApproximatelyEqual(to: candidate)
        }
    }

    // MARK: - Navigation

    func scrollToCharacterOffset(_ offset: Int) {
        let range = NSRange(location: offset, length: 0)
        scrollRangeToVisible(range)
        setSelectedRange(range)
    }

    // MARK: - Data Detection Click

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let idx = characterIndexForInsertion(at: point)
        if idx < (textStorage?.length ?? 0),
           let item = textStorage?.attribute(
               DataDetectionService.detectedDataKey, at: idx, effectiveRange: nil
           ) as? DataDetectionService.DetectedItem {
            DataDetectionService.open(item)
            return
        }
        super.mouseDown(with: event)
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

private extension NSColor {
    func isApproximatelyEqual(to other: NSColor, tolerance: CGFloat = 0.02) -> Bool {
        guard let lhs = usingColorSpace(.deviceRGB),
              let rhs = other.usingColorSpace(.deviceRGB) else {
            return self == other
        }

        return abs(lhs.redComponent - rhs.redComponent) <= tolerance
            && abs(lhs.greenComponent - rhs.greenComponent) <= tolerance
            && abs(lhs.blueComponent - rhs.blueComponent) <= tolerance
            && abs(lhs.alphaComponent - rhs.alphaComponent) <= tolerance
    }
}
