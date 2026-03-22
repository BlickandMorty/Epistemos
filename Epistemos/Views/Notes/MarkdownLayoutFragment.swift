import AppKit

/// Lightweight Swift bridge for CodeToken from Rust FFI.
/// UTF-16 offsets within the paragraph text for direct NSAttributedString use.
struct CodeTokenBridge {
    let start: Int       // UTF-16 offset within paragraph
    let end: Int         // UTF-16 offset (exclusive)
    let tokenType: UInt8
}

/// Custom NSTextLayoutFragment for code block paragraphs.
/// Stores token data and theme for fragment-level rendering.
/// Non-code paragraphs use the default NSTextLayoutFragment.
///
/// Phase 1: Token coloring applied via attributed string attributes in the delegate.
/// Phase 2 (future): Direct Core Graphics rendering in draw(at:in:) with bitmap cache.
final class MarkdownLayoutFragment: NSTextLayoutFragment {

    private(set) var codeTokens: [CodeTokenBridge] = []
    private(set) var fragmentTheme: EpistemosTheme = .nativeDefault
    private(set) var languageId: UInt8 = 0

    /// Bitmap cache for future CG rendering (Phase 2).
    private var cachedImage: CGImage?

    nonisolated override init(textElement: NSTextElement, range rangeInElement: NSTextRange?) {
        super.init(textElement: textElement, range: rangeInElement)
    }

    @available(*, unavailable)
    nonisolated required init?(coder: NSCoder) {
        fatalError("Not supported")
    }

    /// Configure with code token data after framework initialization.
    func configure(tokens: [CodeTokenBridge], theme: EpistemosTheme, languageId: UInt8) {
        self.codeTokens = tokens
        self.fragmentTheme = theme
        self.languageId = languageId
        cachedImage = nil
    }

    func invalidateCache() {
        cachedImage = nil
    }
}
