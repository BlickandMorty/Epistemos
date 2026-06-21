import AppKit

// SS-2S A.2 (owner 2026-06-21): the flag-gated TextKit 2 render that actually SHOWS markdown images
// in the Prose/TK2 editor — the owner wants to SEE the image, not the ghost+accent-chip. A custom
// NSTextLayoutFragment draws the resolved image BELOW the `![](...)` text line; it NEVER replaces
// the text, so the persisted markdown is untouched (a text-mutating attachment would corrupt the
// saved md = a data-loss floor violation). It integrates into ProseTextView2's EXISTING
// NSTextLayoutManagerDelegate fragment provider (the same seam that returns MarkdownLayoutFragment
// for code blocks). Behind a default-OFF flag: flag OFF skips the branch entirely, so the editor is
// BYTE-IDENTICAL to today (zero regression) until the owner flips it on and visually verifies.

enum ProseInlineImageRender {
    /// Default OFF. Owner flips `EPISTEMOS_PROSE_INLINE_IMAGE_V0=1` to enable the inline render.
    static var enabled: Bool {
        ProcessInfo.processInfo.environment["EPISTEMOS_PROSE_INLINE_IMAGE_V0"] == "1"
    }

    /// The decision the fragment provider makes for one paragraph: when the flag is on AND the
    /// paragraph's text is an inline `![alt](src)` image with a resolvable src, return the asset URL
    /// to draw; otherwise nil (→ the default fragment, no image). Isolated + pure so the selection
    /// logic is headless-testable without TextKit. noteDirectory nil → only absolute / remote /
    /// home `~/` srcs resolve (honest; no guessed base).
    static func imageURL(forParagraphText text: String, noteDirectory: URL?, enabled: Bool) -> URL? {
        guard enabled else { return nil }
        return ProseInlineImage.resolveURL(fromMarkdownSpan: text, noteDirectory: noteDirectory)
    }
}

/// A layout fragment that reserves space below the text line and draws the resolved image there —
/// without altering the text. All draw math is defensive (guards nil / zero) so a missing or
/// oversized image can never crash the editor.
///
/// Isolation: NSTextLayoutFragment's init / geometry / draw are `nonisolated` in the SDK, so the
/// overrides must be `nonisolated` too (this module defaults to MainActor isolation). The image is
/// loaded SYNCHRONOUSLY on first draw for local file URLs (the common case for inserted assets), so
/// nothing crosses an isolation boundary — an async + downsampled load via
/// `NoteImageProcessor.loadDisplayImage` (and remote `http(s)` support) is the next increment, but it
/// requires sending non-Sendable layout state across actors, so it's deferred rather than faked here.
final class ProseInlineImageLayoutFragment: NSTextLayoutFragment {
    // SAFETY: `imageURL` is set once by the fragment provider on the main thread right after init;
    // `loadedImage` / `didAttemptLoad` are only ever read or written inside draw() and the geometry
    // getters, which AppKit always invokes on the main thread. There is no concurrent access, so the
    // nonisolated(unsafe) storage (required because the overrides are nonisolated) is race-free.
    nonisolated(unsafe) var imageURL: URL?
    nonisolated(unsafe) private var loadedImage: NSImage?
    nonisolated(unsafe) private var didAttemptLoad = false
    nonisolated private static let maxImageHeight: CGFloat = 240
    nonisolated private static let gap: CGFloat = 6

    nonisolated override init(textElement: NSTextElement, range rangeInElement: NSTextRange?) {
        super.init(textElement: textElement, range: rangeInElement)
    }

    nonisolated required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    nonisolated private func scaledSize(baseWidth: CGFloat) -> CGSize {
        guard let img = loadedImage, img.size.width > 0, img.size.height > 0 else { return .zero }
        let maxW = baseWidth > 1 ? baseWidth : img.size.width
        let scale = min(1, min(maxW / img.size.width, Self.maxImageHeight / img.size.height))
        return CGSize(width: img.size.width * scale, height: img.size.height * scale)
    }

    nonisolated override var layoutFragmentFrame: CGRect {
        var frame = super.layoutFragmentFrame
        let extra = scaledSize(baseWidth: frame.width).height
        if extra > 0 { frame.size.height += extra + Self.gap }
        return frame
    }

    nonisolated override var renderingSurfaceBounds: CGRect {
        let base = super.renderingSurfaceBounds
        let frame = super.layoutFragmentFrame
        let size = scaledSize(baseWidth: frame.width)
        guard size.height > 0 else { return base }
        return CGRect(
            x: base.minX,
            y: base.minY,
            width: max(base.width, size.width),
            height: frame.height + size.height + Self.gap)
    }

    nonisolated override func draw(at point: CGPoint, in context: CGContext) {
        super.draw(at: point, in: context)  // the md text line — unchanged
        loadImageIfNeeded()
        let frame = super.layoutFragmentFrame
        let size = scaledSize(baseWidth: frame.width)
        guard let image = loadedImage, size.height > 0 else { return }
        let rect = CGRect(
            x: point.x, y: point.y + frame.height + Self.gap, width: size.width, height: size.height)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
        image.draw(
            in: rect, from: .zero, operation: .sourceOver, fraction: 1.0,
            respectFlipped: true, hints: nil)
        NSGraphicsContext.restoreGraphicsState()
    }

    /// Loads the image once, synchronously, for local file URLs (no network on the draw path), then
    /// invalidates layout so the height reservation picks up the now-known size on the next pass.
    /// Remote `http(s)` srcs are skipped here — the async-load refinement is the next increment.
    nonisolated private func loadImageIfNeeded() {
        guard loadedImage == nil, !didAttemptLoad, let url = imageURL else { return }
        didAttemptLoad = true
        guard url.isFileURL, let image = NSImage(contentsOf: url) else { return }
        loadedImage = image
        textLayoutManager?.invalidateLayout(for: rangeInElement)
    }
}
