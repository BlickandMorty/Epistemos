import AppKit
import SwiftUI
@testable import Epistemos

@MainActor
final class ClickableTextView: NSTextView {
    nonisolated static let createIdeaNotification = ProseTextView2.createIdeaNotification
    nonisolated static let createBrainDumpNotification = ProseTextView2.createBrainDumpNotification
    nonisolated static let aiOperationNotification = ProseTextView2.aiOperationNotification
    nonisolated static let blockPropertyNotification = ProseTextView2.blockPropertyNotification
    nonisolated static let translateNotification = ProseTextView2.translateNotification
    nonisolated static let scrollToOffsetNotification = ProseTextView2.scrollToOffsetNotification

    nonisolated(unsafe) var usesRenderedTableOverlays = false
    nonisolated(unsafe) var hasProtectedInlineResponseDivider = false
    var pageUndoManager: UndoManager?

    override var undoManager: UndoManager? {
        pageUndoManager ?? super.undoManager
    }

    override func shouldChangeText(
        in affectedCharRange: NSRange,
        replacementString: String?
    ) -> Bool {
        if hasProtectedInlineResponseDivider,
           NoteChatInlineResponse.editTouchesDivider(in: string, affectedRange: affectedCharRange) {
            return false
        }
        return super.shouldChangeText(in: affectedCharRange, replacementString: replacementString)
    }
}

private struct LegacyColorSnapshot: Sendable {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
    let alpha: CGFloat

    nonisolated init?(_ color: NSColor?) {
        guard let color else { return nil }
        let resolved = color.usingColorSpace(.sRGB) ?? color.usingColorSpace(.deviceRGB)
        guard let resolved else { return nil }
        red = resolved.redComponent
        green = resolved.greenComponent
        blue = resolved.blueComponent
        alpha = resolved.alphaComponent
    }

    nonisolated func makeColor() -> NSColor {
        NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }
}

enum TestColorAssertions {
    nonisolated static func colorsMatch(
        _ lhs: NSColor?,
        _ rhs: NSColor?,
        tolerance: CGFloat = 1.0 / 255.0
    ) -> Bool {
        guard let lhs = LegacyColorSnapshot(lhs), let rhs = LegacyColorSnapshot(rhs) else {
            return false
        }

        return abs(lhs.red - rhs.red) <= tolerance
            && abs(lhs.green - rhs.green) <= tolerance
            && abs(lhs.blue - rhs.blue) <= tolerance
            && abs(lhs.alpha - rhs.alpha) <= tolerance
    }
}

private struct LegacyFontSnapshot: Sendable {
    let name: String?
    let pointSize: CGFloat
    let isRegularUIFont: Bool
    let isMonospaced: Bool
    let weightRawValue: CGFloat
    let isBold: Bool
    let isItalic: Bool

    nonisolated init?(_ font: NSFont?) {
        guard let font else { return nil }
        let manager = NSFontManager.shared
        let traits = manager.traits(of: font)
        let descriptorTraits =
            (font.fontDescriptor.object(forKey: .traits) as? [NSFontDescriptor.TraitKey: Any]) ?? [:]

        isRegularUIFont = AppDisplayTypography.isRegularUIFont(font)
        isMonospaced = font.isFixedPitch || font.fontDescriptor.symbolicTraits.contains(.monoSpace)
        name = isRegularUIFont ? nil : font.fontName
        pointSize = font.pointSize
        weightRawValue = (descriptorTraits[.weight] as? CGFloat)
            ?? (traits.contains(.boldFontMask) ? NSFont.Weight.bold.rawValue : NSFont.Weight.regular.rawValue)
        isBold = traits.contains(.boldFontMask)
        isItalic = traits.contains(.italicFontMask)
    }

    nonisolated func makeFont() -> NSFont {
        if isMonospaced {
            let manager = NSFontManager.shared
            var font = NSFont.monospacedSystemFont(
                ofSize: pointSize,
                weight: NSFont.Weight(rawValue: weightRawValue)
            )

            if isBold {
                font = manager.convert(font, toHaveTrait: .boldFontMask)
            }
            if isItalic {
                font = manager.convert(font, toHaveTrait: .italicFontMask)
            }
            return font
        }

        if isRegularUIFont {
            let manager = NSFontManager.shared
            var font = AppDisplayTypography.regularUIFont(
                size: pointSize,
                weight: NSFont.Weight(rawValue: weightRawValue)
            )

            if isBold {
                font = manager.convert(font, toHaveTrait: .boldFontMask)
            }
            if isItalic {
                font = manager.convert(font, toHaveTrait: .italicFontMask)
            }
            return font
        }

        if let name, let font = NSFont(name: name, size: pointSize) {
            return font
        }
        return NSFont.systemFont(ofSize: pointSize)
    }
}

private struct LegacyParagraphStyleSnapshot: Sendable {
    let firstLineHeadIndent: CGFloat
    let headIndent: CGFloat
    let tailIndent: CGFloat
    let paragraphSpacing: CGFloat
    let paragraphSpacingBefore: CGFloat
    let lineSpacing: CGFloat
    let minimumLineHeight: CGFloat
    let maximumLineHeight: CGFloat
    let alignment: Int

    nonisolated init?(_ style: NSParagraphStyle?) {
        guard let style else { return nil }
        firstLineHeadIndent = style.firstLineHeadIndent
        headIndent = style.headIndent
        tailIndent = style.tailIndent
        paragraphSpacing = style.paragraphSpacing
        paragraphSpacingBefore = style.paragraphSpacingBefore
        lineSpacing = style.lineSpacing
        minimumLineHeight = style.minimumLineHeight
        maximumLineHeight = style.maximumLineHeight
        alignment = style.alignment.rawValue
    }

    nonisolated func makeParagraphStyle() -> NSParagraphStyle {
        let paragraph = NSMutableParagraphStyle()
        paragraph.firstLineHeadIndent = firstLineHeadIndent
        paragraph.headIndent = headIndent
        paragraph.tailIndent = tailIndent
        paragraph.paragraphSpacing = paragraphSpacing
        paragraph.paragraphSpacingBefore = paragraphSpacingBefore
        paragraph.lineSpacing = lineSpacing
        paragraph.minimumLineHeight = minimumLineHeight
        paragraph.maximumLineHeight = maximumLineHeight
        paragraph.alignment = NSTextAlignment(rawValue: alignment) ?? .natural
        return paragraph
    }
}

private struct LegacyAttributeRunSnapshot: Sendable {
    let range: NSRange
    let font: LegacyFontSnapshot?
    let foregroundColor: LegacyColorSnapshot?
    let backgroundColor: LegacyColorSnapshot?
    let paragraphStyle: LegacyParagraphStyleSnapshot?
    let link: String?
    let strikethroughStyle: Int?
    let blockChromeKind: String?
    let blockChromeAccent: LegacyColorSnapshot?
    let blockChromeFill: LegacyColorSnapshot?
}

private struct LegacyStyledMarkdownSnapshot: Sendable {
    let runs: [LegacyAttributeRunSnapshot]

    @MainActor
    static func make(
        markdown: String,
        theme: EpistemosTheme,
        usesRenderedTableOverlays: Bool,
        baseFontSize: CGFloat,
        includeInline: Bool
    ) -> Self {
        let styled = NSMutableAttributedString(string: markdown)
        let fullRange = NSRange(location: 0, length: styled.length)
        styled.setAttributes([
            .font: NSFont.systemFont(ofSize: baseFontSize),
            .foregroundColor: theme.resolved.foreground.nsColor,
            .paragraphStyle: MarkdownEditorStyle.bodyParagraphStyle(),
        ], range: fullRange)

        let delegate = MarkdownContentStorage()
        delegate.theme = theme
        delegate.usesRenderedTableOverlays = usesRenderedTableOverlays
        delegate.reparse(text: markdown)

        let nsString = markdown as NSString
        var location = 0
        var lineIndex = 0
        while location < nsString.length {
            let lineRange = nsString.lineRange(for: NSRange(location: location, length: 0))
            let hasTrailingNewline = lineRange.length > 0
                && lineRange.location + lineRange.length <= nsString.length
                && nsString.character(at: lineRange.location + lineRange.length - 1) == 0x0A
            let styleLength = hasTrailingNewline ? lineRange.length - 1 : lineRange.length
            let styleRange = NSRange(location: lineRange.location, length: max(0, styleLength))
            if styleRange.length > 0 {
                let paragraphType = delegate.paragraphType(at: lineIndex) ?? 0
                let metadata = delegate.paragraphMetadata(at: lineIndex) ?? 0
                delegate.applyStructuralStyleForTest(
                    to: styled,
                    range: styleRange,
                    paraType: paragraphType,
                    metadata: metadata
                )
            }
            let nextLocation = lineRange.location + lineRange.length
            guard nextLocation > location else { break }
            location = nextLocation
            lineIndex += 1
        }

        if includeInline {
            delegate.applyInlineStyles(to: styled, fullRange: fullRange)
        }

        var runs: [LegacyAttributeRunSnapshot] = []
        styled.enumerateAttributes(in: fullRange) { attributes, range, _ in
            let linkValue: String?
            if let link = attributes[.link] as? String {
                linkValue = link
            } else if let link = attributes[.link] as? NSString {
                linkValue = link as String
            } else if let link = attributes[.link] as? URL {
                linkValue = link.absoluteString
            } else {
                linkValue = nil
            }

            let strikethroughStyle =
                (attributes[.strikethroughStyle] as? NSNumber)?.intValue
                ?? (attributes[.strikethroughStyle] as? Int)

            runs.append(
                LegacyAttributeRunSnapshot(
                    range: range,
                    font: LegacyFontSnapshot(attributes[.font] as? NSFont),
                    foregroundColor: LegacyColorSnapshot(attributes[.foregroundColor] as? NSColor),
                    backgroundColor: LegacyColorSnapshot(attributes[.backgroundColor] as? NSColor),
                    paragraphStyle: LegacyParagraphStyleSnapshot(attributes[.paragraphStyle] as? NSParagraphStyle),
                    link: linkValue,
                    strikethroughStyle: strikethroughStyle,
                    blockChromeKind: attributes[MarkdownEditorStyle.blockChromeKindAttribute] as? String,
                    blockChromeAccent: LegacyColorSnapshot(attributes[MarkdownEditorStyle.blockChromeAccentAttribute] as? NSColor),
                    blockChromeFill: LegacyColorSnapshot(attributes[MarkdownEditorStyle.blockChromeFillAttribute] as? NSColor)
                )
            )
        }

        return Self(runs: runs)
    }
}

nonisolated final class MarkdownTextStorage: NSTextStorage {
    nonisolated static let noteBaseFontSize = MarkdownEditorStyle.noteBaseFontSize
    nonisolated static let blockChromeKindAttribute = MarkdownEditorStyle.blockChromeKindAttribute
    nonisolated static let blockChromeAccentAttribute = MarkdownEditorStyle.blockChromeAccentAttribute
    nonisolated static let blockChromeFillAttribute = MarkdownEditorStyle.blockChromeFillAttribute
    nonisolated static let leadingH1SpacingBefore = MarkdownEditorStyle.leadingH1SpacingBefore
    nonisolated static let sectionH1SpacingBefore = MarkdownEditorStyle.sectionH1SpacingBefore
    nonisolated static let bodyIndent = MarkdownEditorStyle.bodyIndent

    typealias TableLineRole = MarkdownEditorStyle.TableLineRole
    typealias BlockChromeSpan = MarkdownEditorStyle.BlockChromeSpan

    private let backing = NSMutableAttributedString()

    var isDark = true
    var theme: EpistemosTheme?
    var usesRenderedTableOverlays = false
    var skipInlineStyles = false
    var skipAllStyling = false
    private(set) var isProcessingEdits = false
    let baseFontSize: CGFloat = MarkdownEditorStyle.noteBaseFontSize

    override var string: String { backing.string }

    override func attributes(
        at location: Int,
        effectiveRange range: NSRangePointer?
    ) -> [NSAttributedString.Key: Any] {
        guard location < backing.length else {
            range?.pointee = NSRange(location: location, length: 0)
            return [:]
        }
        return backing.attributes(at: location, effectiveRange: range)
    }

    override func replaceCharacters(in range: NSRange, with str: String) {
        beginEditing()
        backing.replaceCharacters(in: range, with: str)
        edited(.editedCharacters, range: range, changeInLength: str.utf16.count - range.length)
        endEditing()
    }

    override func setAttributes(_ attrs: [NSAttributedString.Key: Any]?, range: NSRange) {
        guard range.location + range.length <= backing.length else { return }
        beginEditing()
        backing.setAttributes(attrs, range: range)
        edited(.editedAttributes, range: range, changeInLength: 0)
        endEditing()
    }

    override func processEditing() {
        isProcessingEdits = true
        defer { isProcessingEdits = false }

        guard !skipAllStyling else {
            super.processEditing()
            return
        }

        applyStyledContent(includeInline: !skipInlineStyles, notify: false)
        super.processEditing()
    }

    func reapplyAllStyles() {
        applyStyledContent(includeInline: true, notify: true)
    }

    func reapplyLineStyles() {
        applyStyledContent(includeInline: false, notify: true)
    }

    func reapplyStyles(in _: NSRange) {
        applyStyledContent(includeInline: true, notify: true)
    }

    func applyInlineStyles(fullRange _: NSRange) {
        applyStyledContent(includeInline: true, notify: true)
    }

    private func applyStyledContent(includeInline: Bool, notify: Bool) {
        guard backing.length > 0 else { return }

        let markdown = backing.string
        let resolvedTheme = theme ?? (isDark ? .sunset : .light)
        let renderedTableOverlays = usesRenderedTableOverlays
        let resolvedBaseFontSize = baseFontSize
        let snapshot = MainActor.assumeIsolated {
            LegacyStyledMarkdownSnapshot.make(
                markdown: markdown,
                theme: resolvedTheme,
                usesRenderedTableOverlays: renderedTableOverlays,
                baseFontSize: resolvedBaseFontSize,
                includeInline: includeInline
            )
        }
        let styled = NSMutableAttributedString(string: markdown)
        for run in snapshot.runs {
            var attributes: [NSAttributedString.Key: Any] = [:]
            if let font = run.font?.makeFont() {
                attributes[.font] = font
            }
            if let foregroundColor = run.foregroundColor?.makeColor() {
                attributes[.foregroundColor] = foregroundColor
            }
            if let backgroundColor = run.backgroundColor?.makeColor() {
                attributes[.backgroundColor] = backgroundColor
            }
            if let paragraphStyle = run.paragraphStyle?.makeParagraphStyle() {
                attributes[.paragraphStyle] = paragraphStyle
            }
            if let link = run.link {
                attributes[.link] = link
            }
            if let strikethroughStyle = run.strikethroughStyle {
                attributes[.strikethroughStyle] = strikethroughStyle
            }
            if let blockChromeKind = run.blockChromeKind {
                attributes[MarkdownEditorStyle.blockChromeKindAttribute] = blockChromeKind
            }
            if let blockChromeAccent = run.blockChromeAccent?.makeColor() {
                attributes[MarkdownEditorStyle.blockChromeAccentAttribute] = blockChromeAccent
            }
            if let blockChromeFill = run.blockChromeFill?.makeColor() {
                attributes[MarkdownEditorStyle.blockChromeFillAttribute] = blockChromeFill
            }
            styled.setAttributes(attributes, range: run.range)
        }
        backing.setAttributedString(styled)
        if notify {
            edited(.editedAttributes, range: NSRange(location: 0, length: styled.length), changeInLength: 0)
        }
    }

    nonisolated static func bodyParagraphStyle() -> NSParagraphStyle {
        MarkdownEditorStyle.bodyParagraphStyle()
    }

    nonisolated static func headingParagraphStyle(level: Int, isLeadingDocumentHeading: Bool) -> NSParagraphStyle {
        MarkdownEditorStyle.headingParagraphStyle(
            level: level,
            isLeadingDocumentHeading: isLeadingDocumentHeading
        )
    }

    nonisolated static func calloutParagraphStyle() -> NSParagraphStyle {
        MarkdownEditorStyle.calloutParagraphStyle()
    }

    nonisolated static func codeBlockParagraphStyle() -> NSParagraphStyle {
        MarkdownEditorStyle.codeBlockParagraphStyle()
    }

    nonisolated static func quoteParagraphStyle() -> NSParagraphStyle {
        MarkdownEditorStyle.quoteParagraphStyle()
    }

    nonisolated static func listParagraphStyle() -> NSParagraphStyle {
        MarkdownEditorStyle.listParagraphStyle()
    }

    nonisolated static func tableParagraphStyle() -> NSParagraphStyle {
        MarkdownEditorStyle.tableParagraphStyle()
    }

    nonisolated static func tablePlaceholderParagraphStyle() -> NSParagraphStyle {
        MarkdownEditorStyle.tablePlaceholderParagraphStyle()
    }

    nonisolated static func tableCollapsedParagraphStyle() -> NSParagraphStyle {
        MarkdownEditorStyle.tableCollapsedParagraphStyle()
    }

    nonisolated static func tableSeparatorParagraphStyle() -> NSParagraphStyle {
        MarkdownEditorStyle.tableSeparatorParagraphStyle()
    }

    nonisolated static func tableLineRole(at range: NSRange, in text: NSString) -> TableLineRole {
        MarkdownEditorStyle.tableLineRole(at: range, in: text)
    }

    nonisolated static func blockChromeFill(
        from attributes: [NSAttributedString.Key: Any],
        fallback: NSColor = .controlBackgroundColor
    ) -> NSColor {
        MarkdownEditorStyle.blockChromeFill(from: attributes, fallback: fallback)
    }

    nonisolated static func blockChromeStyleRange(in text: NSString, lineRange: NSRange) -> NSRange {
        MarkdownEditorStyle.blockChromeStyleRange(in: text, lineRange: lineRange)
    }

    nonisolated static func blockChromeSpan(
        in attributedString: NSAttributedString,
        text: NSString,
        aroundLineRange lineRange: NSRange
    ) -> BlockChromeSpan? {
        MarkdownEditorStyle.blockChromeSpan(
            in: attributedString,
            text: text,
            aroundLineRange: lineRange
        )
    }

    nonisolated static func blockChromeFrame(
        textContainerOrigin: NSPoint,
        containerWidth: CGFloat,
        boundsWidth: CGFloat
    ) -> NSRect {
        MarkdownEditorStyle.blockChromeFrame(
            textContainerOrigin: textContainerOrigin,
            containerWidth: containerWidth,
            boundsWidth: boundsWidth
        )
    }

    nonisolated static func drawBlockChrome(
        kind: MarkdownBlockChromeKind,
        fill: NSColor,
        accent: NSColor,
        in rect: NSRect
    ) {
        MarkdownEditorStyle.drawBlockChrome(kind: kind, fill: fill, accent: accent, in: rect)
    }
}

@MainActor
final class PageStoragePool {
    static let shared = PageStoragePool()

    struct PageSlot {
        let storage: MarkdownTextStorage
        let undoManager: UndoManager
        var scrollY: CGFloat
        var selectionRange: NSRange
        var theme: EpistemosTheme
        var lastAccessedAt: Date
    }

    private var slots: [String: PageSlot] = [:]

    private init() {}

    func getOrCreate(pageId: String, bodyText: String, theme: EpistemosTheme) -> PageSlot {
        if var existing = slots[pageId] {
            existing.storage.usesRenderedTableOverlays = false
            if existing.storage.string != bodyText {
                existing.storage.replaceCharacters(
                    in: NSRange(location: 0, length: existing.storage.length),
                    with: bodyText
                )
                existing.storage.reapplyAllStyles()
            }
            existing.theme = theme
            existing.lastAccessedAt = .now
            slots[pageId] = existing
            return existing
        }

        let storage = MarkdownTextStorage()
        storage.theme = theme
        storage.isDark = theme.isDark
        storage.usesRenderedTableOverlays = false
        storage.replaceCharacters(in: NSRange(location: 0, length: storage.length), with: bodyText)
        storage.reapplyAllStyles()

        let slot = PageSlot(
            storage: storage,
            undoManager: UndoManager(),
            scrollY: 0,
            selectionRange: NSRange(location: 0, length: 0),
            theme: theme,
            lastAccessedAt: .now
        )
        slots[pageId] = slot
        return slot
    }

    func bodyText(for pageId: String) -> String? {
        slots[pageId]?.storage.string
    }

    func saveState(pageId: String, scrollY: CGFloat, selection: NSRange) {
        guard var slot = slots[pageId] else { return }
        slot.scrollY = scrollY
        slot.selectionRange = selection
        slot.lastAccessedAt = .now
        slots[pageId] = slot
    }

    func saveToDisk(pageId _: String) {}

    func invalidateExcept(activePageId: String?) {
        slots = slots.filter { $0.key == activePageId }
    }

    func preWarm(pages: [(id: String, body: String)], theme: EpistemosTheme) {
        for page in pages {
            _ = getOrCreate(pageId: page.id, bodyText: page.body, theme: theme)
        }
    }

    func preWarmRecent(pages: [(id: String, body: String)], theme: EpistemosTheme) {
        preWarm(pages: pages, theme: theme)
    }

    func remove(pageId: String) {
        slots.removeValue(forKey: pageId)
    }

    func removeAll() {
        slots.removeAll()
    }
}

@MainActor
struct ProseEditorRepresentable: NSViewRepresentable {
    @Binding var text: String
    let pageId: String
    let pageBody: String
    let isFocused: Bool
    let theme: EpistemosTheme
    let isEditable: Bool
    let isFocusMode: Bool

    nonisolated static let verticalInset: CGFloat = 40

    nonisolated static func horizontalInset(for availableWidth: CGFloat, markdown: String) -> CGFloat {
        _ = availableWidth
        _ = markdown
        return 60
    }

    nonisolated static func typingAttributes(for theme: EpistemosTheme) -> [NSAttributedString.Key: Any] {
        let paragraph =
            (MarkdownEditorStyle.bodyParagraphStyle().mutableCopy() as? NSMutableParagraphStyle)
            ?? NSMutableParagraphStyle()
        return [
            .font: NSFont.systemFont(ofSize: MarkdownEditorStyle.noteBaseFontSize),
            .foregroundColor: NSColor(Color(hex: theme.foregroundHex)),
            .paragraphStyle: paragraph,
        ]
    }

    nonisolated static func matchesNotificationPageId(
        _ notificationPageId: String?,
        coordinatorPageId: String?
    ) -> Bool {
        guard let notificationPageId, !notificationPageId.isEmpty,
              let coordinatorPageId, !coordinatorPageId.isEmpty else {
            return false
        }
        return notificationPageId == coordinatorPageId
    }

    final class Coordinator: NSObject {
        var frameObserver: (any NSObjectProtocol)?
        var scrollObserver: (any NSObjectProtocol)?
        var lastPageId: String?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context _: Context) -> NSScrollView {
        NSScrollView()
    }

    func updateNSView(_: NSScrollView, context _: Context) {}

    nonisolated static func dismantleNSView(_: NSScrollView, coordinator: Coordinator) {
        MainActor.assumeIsolated {
            if let observer = coordinator.frameObserver {
                NotificationCenter.default.removeObserver(observer)
                coordinator.frameObserver = nil
            }
            if let observer = coordinator.scrollObserver {
                NotificationCenter.default.removeObserver(observer)
                coordinator.scrollObserver = nil
            }
        }
    }
}
