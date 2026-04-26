import Foundation

// MARK: - EpdocPasteClassifier
//
// Wave 7.17.b paste-as-block intelligence. Pure-Swift classifier
// that inspects pasted text and decides which Tiptap block type
// the user almost certainly meant. The JS-side paste handler
// (W7.17.b runtime, deferred) ferries pasted text across the
// bridge → calls this classifier → dispatches the matching
// `insertSlashChoice(blockType:)` command.
//
// Per the W7.17.b plan: "YouTube URL → embed; markdown table →
// real Tiptap table; mermaid fence → live diagram; code →
// language-detected code block." Alexandrie's paste handler only
// does file uploads.

nonisolated public enum EpdocPasteIntent: Equatable, Sendable {
    /// Plain text — let the editor's default paste run.
    case plainText
    /// `https://youtube.com/...` or `youtu.be/...` — wrap in a
    /// YouTube embed node.
    case youtubeEmbed(url: String, videoID: String)
    /// `https?://…` URL — wrap in a Link mark + the URL text.
    case url(String)
    /// Markdown pipe-table — convert into a real Tiptap table node
    /// with the parsed (rows, cols) shape.
    case markdownTable(rowCount: Int, columnCount: Int)
    /// `\`\`\`mermaid` fenced block — wrap in the W7.9 Mermaid node.
    case mermaidFence(diagram: String)
    /// `\`\`\`<lang>` fenced block — wrap in code_block w/ language hint.
    case codeFence(language: String?, body: String)
    /// Bare code-shaped text (lots of indents, semicolons / braces) —
    /// wrap in a code block with the detected language guess.
    case detectedCode(language: String, body: String)
    /// Markdown checklist (- [ ] / - [x]) — convert to task_list.
    case markdownTaskList
}

nonisolated public enum EpdocPasteClassifier {

    /// Classify a pasted clipboard payload. Pure function; no I/O.
    public static func classify(_ pasted: String) -> EpdocPasteIntent {
        let trimmed = pasted.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return .plainText }

        // YouTube — short-circuit before generic URL detection so
        // youtube.com → embed, not link.
        if let videoID = youtubeVideoID(from: trimmed) {
            return .youtubeEmbed(url: trimmed, videoID: videoID)
        }

        // Generic URL — single line, scheme-prefixed.
        if isSingleLineURL(trimmed) {
            return .url(trimmed)
        }

        // Mermaid fence first (it's a code fence with a special lang).
        if let mermaid = mermaidFenceBody(trimmed) {
            return .mermaidFence(diagram: mermaid)
        }

        // Generic code fence ```<lang>\n...\n```
        if let (language, body) = codeFenceBody(trimmed) {
            return .codeFence(language: language, body: body)
        }

        // Markdown task list (≥1 line of `- [ ]` / `- [x]`).
        if isMarkdownTaskList(trimmed) {
            return .markdownTaskList
        }

        // Markdown pipe-table (≥2 rows separated by `|---|---|` divider).
        if let (rows, cols) = markdownPipeTableShape(trimmed) {
            return .markdownTable(rowCount: rows, columnCount: cols)
        }

        // Bare code heuristic: ≥3 lines AND ≥1 line starts with 2+ leading
        // spaces / tab AND the body contains either ; or { or = or fn/def/class.
        if looksLikeCode(trimmed) {
            return .detectedCode(language: guessCodeLanguage(trimmed), body: trimmed)
        }

        return .plainText
    }

    // MARK: - YouTube

    /// Extract the 11-char YouTube video id from the canonical URL
    /// shapes:
    ///   https://www.youtube.com/watch?v=<id>
    ///   https://youtu.be/<id>
    ///   https://www.youtube.com/embed/<id>
    static func youtubeVideoID(from url: String) -> String? {
        let lower = url.lowercased()
        guard lower.contains("youtube.com") || lower.contains("youtu.be") else {
            return nil
        }
        // Try `v=` query param first
        if let range = url.range(of: "v=") {
            let after = url[range.upperBound...]
            let id = after.prefix { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
            if id.count == 11 { return String(id) }
        }
        // Try `youtu.be/<id>`
        if let range = url.range(of: "youtu.be/") {
            let after = url[range.upperBound...]
            let id = after.prefix { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
            if id.count == 11 { return String(id) }
        }
        // Try `/embed/<id>`
        if let range = url.range(of: "/embed/") {
            let after = url[range.upperBound...]
            let id = after.prefix { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
            if id.count == 11 { return String(id) }
        }
        return nil
    }

    // MARK: - URL

    static func isSingleLineURL(_ s: String) -> Bool {
        guard !s.contains("\n"), !s.contains(" ") else { return false }
        let lower = s.lowercased()
        return lower.hasPrefix("http://") || lower.hasPrefix("https://") || lower.hasPrefix("file://")
    }

    // MARK: - Code fences

    static func mermaidFenceBody(_ s: String) -> String? {
        let lines = s.split(separator: "\n", omittingEmptySubsequences: false)
        guard lines.count >= 2 else { return nil }
        let first = lines[0].trimmingCharacters(in: .whitespaces).lowercased()
        let last = lines.last?.trimmingCharacters(in: .whitespaces) ?? ""
        guard first == "```mermaid", last == "```" else { return nil }
        let body = lines.dropFirst().dropLast().joined(separator: "\n")
        return body
    }

    static func codeFenceBody(_ s: String) -> (String?, String)? {
        let lines = s.split(separator: "\n", omittingEmptySubsequences: false)
        guard lines.count >= 2 else { return nil }
        let first = lines[0].trimmingCharacters(in: .whitespaces)
        let last = lines.last?.trimmingCharacters(in: .whitespaces) ?? ""
        guard first.hasPrefix("```"), last == "```" else { return nil }
        let lang = String(first.dropFirst(3)).lowercased()
        let body = lines.dropFirst().dropLast().joined(separator: "\n")
        return (lang.isEmpty ? nil : lang, body)
    }

    // MARK: - Task list

    static func isMarkdownTaskList(_ s: String) -> Bool {
        let lines = s.split(separator: "\n")
        return lines.contains { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return trimmed.hasPrefix("- [ ]") || trimmed.hasPrefix("- [x]") || trimmed.hasPrefix("- [X]")
        }
    }

    // MARK: - Markdown pipe-table

    static func markdownPipeTableShape(_ s: String) -> (rowCount: Int, columnCount: Int)? {
        let lines = s.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        guard lines.count >= 2 else { return nil }
        // First row: headers `| h1 | h2 | h3 |`
        // Second row: separator `|---|---|---|`
        let header = lines[0]
        let separator = lines[1]
        guard header.hasPrefix("|") && header.hasSuffix("|") else { return nil }
        guard separator.contains("---") else { return nil }
        let columnCount = header.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.count
        guard columnCount >= 1 else { return nil }
        let rowCount = lines.count - 1  // exclude separator
        return (rowCount, columnCount)
    }

    // MARK: - Generic code heuristic

    static func looksLikeCode(_ s: String) -> Bool {
        let lines = s.split(separator: "\n")
        guard lines.count >= 3 else { return false }
        let hasIndent = lines.contains { line in
            line.hasPrefix("    ") || line.hasPrefix("\t")
        }
        let hasCodeMarker = s.contains(";") || s.contains("{") || s.contains("=>")
            || s.contains("fn ") || s.contains("def ") || s.contains("class ") || s.contains("function ")
        return hasIndent && hasCodeMarker
    }

    static func guessCodeLanguage(_ s: String) -> String {
        if s.contains("fn ") && s.contains("->") { return "rust" }
        if s.contains("func ") && s.contains(" Swift") || s.contains("import SwiftUI") { return "swift" }
        if s.contains("def ") && s.contains(":") && s.contains("    ") { return "python" }
        if s.contains("function ") || s.contains("=>") || s.contains("const ") { return "javascript" }
        if s.contains("public class ") { return "java" }
        if s.contains("#include") { return "c" }
        return "text"
    }
}
