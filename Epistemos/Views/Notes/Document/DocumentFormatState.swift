import AppKit
import Observation

// MARK: - DocumentFormatState
// Observable format model for Document mode. Lighter than WriterFormatState —
// no page sizing, margins, or academic presets. Just rich text formatting.

@MainActor @Observable
final class DocumentFormatState {

    // MARK: - Typography
    var fontFamily: String = "New York"
    var fontSize: CGFloat = 14
    var isBold: Bool = false
    var isItalic: Bool = false
    var isUnderline: Bool = false
    var isStrikethrough: Bool = false

    // MARK: - Paragraph
    var alignment: NSTextAlignment = .left
    var headingLevel: HeadingLevel = .body

    // MARK: - Heading Levels

    enum HeadingLevel: String, CaseIterable, Sendable {
        case body = "Body"
        case h1 = "Heading 1"
        case h2 = "Heading 2"
        case h3 = "Heading 3"
        case h4 = "Heading 4"

        var fontSize: CGFloat {
            switch self {
            case .body: 14
            case .h1: 28
            case .h2: 22
            case .h3: 18
            case .h4: 15
            }
        }

        var isBold: Bool {
            self != .body
        }
    }

    // MARK: - Resolved Font

    var resolvedFont: NSFont {
        let size = headingLevel == .body ? fontSize : headingLevel.fontSize
        var font = NSFont(name: fontFamily, size: size)
            ?? NSFont.systemFont(ofSize: size)

        let manager = NSFontManager.shared
        if isBold || headingLevel.isBold {
            font = manager.convert(font, toHaveTrait: .boldFontMask)
        }
        if isItalic {
            font = manager.convert(font, toHaveTrait: .italicFontMask)
        }
        return font
    }

    // MARK: - Apply to Selection

    /// Applies current format state to the selected range in the text view.
    func applyToSelection(in textView: NSTextView) {
        let range = textView.selectedRange()
        guard range.length > 0, let storage = textView.textStorage else { return }

        storage.beginEditing()

        // Font
        storage.addAttribute(.font, value: resolvedFont, range: range)

        // Underline
        if isUnderline {
            storage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
        } else {
            storage.removeAttribute(.underlineStyle, range: range)
        }

        // Strikethrough
        if isStrikethrough {
            storage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range)
        } else {
            storage.removeAttribute(.strikethroughStyle, range: range)
        }

        // Alignment
        let paraStyle = NSMutableParagraphStyle()
        paraStyle.alignment = alignment
        paraStyle.lineSpacing = 4
        storage.addAttribute(.paragraphStyle, value: paraStyle, range: range)

        storage.endEditing()
    }

    // MARK: - Read from Selection

    /// Reads format state from the attributes at the current selection/cursor.
    func readFromSelection(in textView: NSTextView) {
        let loc = textView.selectedRange().location
        guard loc < (textView.textStorage?.length ?? 0),
              let attrs = textView.textStorage?.attributes(at: loc, effectiveRange: nil)
        else { return }

        if let font = attrs[.font] as? NSFont {
            let traits = NSFontManager.shared.traits(of: font)
            isBold = traits.contains(.boldFontMask)
            isItalic = traits.contains(.italicFontMask)
            fontFamily = font.familyName ?? "New York"
            fontSize = font.pointSize
        }

        isUnderline = (attrs[.underlineStyle] as? Int) != nil
        isStrikethrough = (attrs[.strikethroughStyle] as? Int) != nil

        if let paraStyle = attrs[.paragraphStyle] as? NSParagraphStyle {
            alignment = paraStyle.alignment
        }
    }
}
