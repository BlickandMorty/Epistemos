import Foundation

/// VAULT-DEEP-INTEGRATION §720 (#4): the editor-agnostic CORE of IN-EDITOR agent edits — a structured edit
/// an agent proposes to a note's markdown, applied ROBUSTLY by text (no fragile character offsets). The live
/// editors (Prose `NSTextView` / Epdoc Tiptap) apply the SAME operations to their buffers, and the change is
/// recorded as an agent `MutationEnvelope` (`SourceOp.artifactUpdate`) for provenance. This slice is the
/// operation model + application; the live-editor binding + EventStore provenance wiring are the follow-on.
///
/// HONEST: anchor-based edits return `nil` when the anchor isn't found — the agent never silently mangles a
/// note when its target text is absent; the caller surfaces the miss (no fake "applied").
enum AgentNoteEdit: Sendable, Equatable {
    /// Append text to the end of the note (a separating newline is added when needed).
    case append(String)
    /// Replace the FIRST occurrence of `find` with `replacement`. `nil` when `find` is absent.
    case replaceFirst(find: String, with: String)
    /// Insert `text` immediately after the first occurrence of `anchor` (e.g. a heading). `nil` when absent.
    case insertAfter(anchor: String, text: String)

    /// Apply to a note's content. Returns the new content, or `nil` when an anchor-based edit can't find its
    /// anchor (honest failure — never a silent corruption).
    func apply(to content: String) -> String? {
        switch self {
        case .append(let text):
            if content.isEmpty { return text }
            let separator = content.hasSuffix("\n") ? "" : "\n"
            return content + separator + text
        case .replaceFirst(let find, let replacement):
            guard !find.isEmpty, let range = content.range(of: find) else { return nil }
            return content.replacingCharacters(in: range, with: replacement)
        case .insertAfter(let anchor, let text):
            guard !anchor.isEmpty, let range = content.range(of: anchor) else { return nil }
            var out = content
            let insertion = (text.hasPrefix("\n") ? "" : "\n") + text
            out.insert(contentsOf: insertion, at: range.upperBound)
            return out
        }
    }

    /// LIVE-EDITOR binding (§720 #4): resolve this edit to a `MarkdownEditorCommands.TextEdit` (NSRange +
    /// replacement text + post-edit selection) against the editor's CURRENT buffer text, so it can be applied
    /// to an OPEN Prose/Epdoc buffer via the existing programmatic-edit path (`applyAutomaticMarkdownEdit`) —
    /// reuse-not-rebuild. Returns `nil` when the find/anchor is absent — the SAME honest no-silent-mangle
    /// contract as `apply(to:)`, now against the live buffer.
    func resolveTextEdit(in liveText: String) -> MarkdownEditorCommands.TextEdit? {
        let ns = liveText as NSString
        switch self {
        case .append(let text):
            let insertion = (liveText.isEmpty || liveText.hasSuffix("\n")) ? text : "\n" + text
            let at = ns.length
            return .init(
                replacementRange: NSRange(location: at, length: 0),
                replacementText: insertion,
                selectedRange: NSRange(location: at + (insertion as NSString).length, length: 0))
        case .replaceFirst(let find, let replacement):
            guard !find.isEmpty else { return nil }
            let r = ns.range(of: find)
            guard r.location != NSNotFound else { return nil }
            return .init(
                replacementRange: r,
                replacementText: replacement,
                selectedRange: NSRange(location: r.location + (replacement as NSString).length, length: 0))
        case .insertAfter(let anchor, let text):
            guard !anchor.isEmpty else { return nil }
            let r = ns.range(of: anchor)
            guard r.location != NSNotFound else { return nil }
            let at = r.location + r.length
            let insertion = text.hasPrefix("\n") ? text : "\n" + text
            return .init(
                replacementRange: NSRange(location: at, length: 0),
                replacementText: insertion,
                selectedRange: NSRange(location: at + (insertion as NSString).length, length: 0))
        }
    }

    /// Apply a SEQUENCE of edits ATOMICALLY (in order). Returns the final content, or `nil` if ANY edit
    /// fails (a missing anchor) — all-or-nothing, so an agent's multi-edit batch can never leave a note
    /// half-applied / partially corrupted. The honest contract extended to batches: the caller re-plans
    /// the whole edit rather than committing a broken partial.
    static func apply(_ edits: [AgentNoteEdit], to content: String) -> String? {
        var current = content
        for edit in edits {
            guard let next = edit.apply(to: current) else { return nil }
            current = next
        }
        return current
    }
}
