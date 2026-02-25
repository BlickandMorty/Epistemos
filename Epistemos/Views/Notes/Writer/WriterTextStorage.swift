import AppKit

// MARK: - WriterTextStorage
// NSTextStorage subclass that applies uniform rich-text formatting for
// academic / word-processor style documents. Unlike MarkdownTextStorage,
// this does not parse markdown syntax — it applies the same font, color,
// and paragraph style uniformly to all text, driven by WriterFormatState.
//
// Performance contract:
// - processEditing() is O(paragraph) per keystroke.
// - reapplyFormatting() is O(document) — called on load and format change.

nonisolated(unsafe) final class WriterTextStorage: NSTextStorage {
    private let backing = NSMutableAttributedString()
    var formatState: WriterFormatState?
    var isDark: Bool = false
    var skipFormatting = false

    // MARK: - NSTextStorage Overrides

    override var string: String { backing.string }

    override func attributes(at location: Int, effectiveRange range: NSRangePointer?) -> [NSAttributedString.Key: Any] {
        guard location < backing.length else {
            range?.pointee = NSRange(location: location, length: 0)
            return [:]
        }
        return backing.attributes(at: location, effectiveRange: range)
    }

    override func replaceCharacters(in range: NSRange, with str: String) {
        beginEditing()
        backing.replaceCharacters(in: range, with: str)
        edited(.editedCharacters, range: range,
               changeInLength: str.utf16.count - range.length)
        endEditing()
    }

    override func setAttributes(_ attrs: [NSAttributedString.Key: Any]?, range: NSRange) {
        guard range.location + range.length <= backing.length else { return }
        beginEditing()
        backing.setAttributes(attrs, range: range)
        edited(.editedAttributes, range: range, changeInLength: 0)
        endEditing()
    }

    // MARK: - Incremental Formatting (O(paragraph) per keystroke)

    override func processEditing() {
        if !skipFormatting && backing.length > 0 {
            let editedRange = self.editedRange
            if editedRange.location != NSNotFound {
                let paraRange = (string as NSString).paragraphRange(for: editedRange)
                applyFormatting(range: paraRange)
            }
        }
        super.processEditing()
    }

    // MARK: - Formatting

    /// Applies uniform academic formatting (font, color, paragraph style) to the given range.
    func applyFormatting(range: NSRange) {
        guard range.location + range.length <= backing.length else { return }

        let font: NSFont
        let paragraphStyle: NSParagraphStyle

        if let state = formatState {
            font = state.resolvedFont
            paragraphStyle = state.resolvedParagraphStyle
        } else {
            // Fallback defaults when no format state is set
            font = NSFont(name: "Times New Roman", size: 12) ?? NSFont.systemFont(ofSize: 12)
            let ps = NSMutableParagraphStyle()
            ps.lineSpacing = 4
            paragraphStyle = ps.copy() as! NSParagraphStyle
        }

        backing.setAttributes([
            .font: font,
            .foregroundColor: resolvedTextColor,
            .paragraphStyle: paragraphStyle
        ], range: range)
    }

    /// Re-applies formatting to the entire document. Called on load and when
    /// format state changes (font, spacing, alignment, etc.).
    func reapplyFormatting() {
        guard backing.length > 0 else { return }
        let fullRange = NSRange(location: 0, length: backing.length)
        beginEditing()
        applyFormatting(range: fullRange)
        edited(.editedAttributes, range: fullRange, changeInLength: 0)
        endEditing()
    }

    // MARK: - Theme Colors

    /// Text color matching the current theme (dark or light).
    private var resolvedTextColor: NSColor {
        isDark
            ? NSColor.white.withAlphaComponent(0.88)
            : NSColor(white: 0.1, alpha: 1)
    }

    // MARK: - PDF Export Helpers

    /// Temporarily sets all text to black for PDF/print export.
    func setExportColors() {
        guard backing.length > 0 else { return }
        let fullRange = NSRange(location: 0, length: backing.length)
        beginEditing()
        backing.addAttributes([
            .foregroundColor: NSColor.black
        ], range: fullRange)
        edited(.editedAttributes, range: fullRange, changeInLength: 0)
        endEditing()
    }

    /// Restores theme colors after PDF export by re-applying all formatting.
    func restoreThemeColors() {
        reapplyFormatting()
    }
}
