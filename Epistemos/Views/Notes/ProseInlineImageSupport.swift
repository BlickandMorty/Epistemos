import Foundation

// SS-2S A.2 (owner 2026-06-21): full inline-image render in the Prose/TK2 editor — the owner wants
// to SEE the image, not the ghost+accent-chip caveat. ProseTextView2 is TextKit 2
// (NSTextLayoutManager), so the SAFE render is a layout-layer draw over the `![](...)` range that
// NEVER mutates the persisted md text (a naive NSTextAttachment that replaced the span would corrupt
// the saved markdown = data loss). That draw consumes ONE input: the asset URL for an image span.
//
// This is that input, isolated as a PURE, headless-testable resolver. It composes with the existing
// `NoteImageProcessor.loadDisplayImage(from: URL)` (which loads a *resolved* URL): the render will
// call `ProseInlineImage.resolveURL(...)` → `NoteImageProcessor.loadDisplayImage(from:)`. The
// TextKit2 layout-fragment draw itself (behind a default-off flag, since a layout-fragment bug could
// affect the whole editor) is the follow-on increment.
enum ProseInlineImage {

    /// Extract the `src` from an inline `![alt](src)` markdown image span. Returns nil if the span
    /// isn't a well-formed inline image (no `](`, no closing `)`, or an empty src).
    static func source(fromMarkdownSpan span: String) -> String? {
        guard let bracketParen = span.range(of: "](") else { return nil }
        let afterParen = span[bracketParen.upperBound...]
        guard let close = afterParen.firstIndex(of: ")") else { return nil }
        let src = afterParen[..<close].trimmingCharacters(in: .whitespaces)
        return src.isEmpty ? nil : src
    }

    /// Resolve an image `src` to the URL the renderer loads. Handles: http(s) remote URLs; absolute
    /// file paths (`/…`); home-relative (`~/…`); and note-relative (e.g. `assets/<name>`, resolved
    /// against the note's directory). Returns nil for an empty src, or a note-relative src with no
    /// note directory (honest — we don't guess a base).
    static func resolveURL(source src: String, noteDirectory: URL?) -> URL? {
        let trimmed = src.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            return URL(string: trimmed)
        }
        if trimmed.hasPrefix("/") {
            return URL(fileURLWithPath: trimmed)
        }
        if trimmed.hasPrefix("~/") || trimmed == "~" {
            return URL(fileURLWithPath: (trimmed as NSString).expandingTildeInPath)
        }
        // Note-relative (the common case for inserted assets, e.g. assets/<name>).
        guard let noteDirectory else { return nil }
        return noteDirectory.appendingPathComponent(trimmed)
    }

    /// Convenience: parse the `![alt](src)` span and resolve its src in one step.
    static func resolveURL(fromMarkdownSpan span: String, noteDirectory: URL?) -> URL? {
        guard let src = source(fromMarkdownSpan: span) else { return nil }
        return resolveURL(source: src, noteDirectory: noteDirectory)
    }
}
