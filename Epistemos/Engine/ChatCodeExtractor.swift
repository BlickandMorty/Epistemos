import Foundation

// MARK: - ChatCodeExtractor
//
// Wave 9.4 of the Extended Program Plan
// (cross-ref `epistemos_code_verdict.md` §"unified provenance" + brain
//  dump 2026-04-26).
//
// When an agent's chat message contains a fenced code block:
//
//     ```swift
//     func hello() { print("hi") }
//     ```
//
// the extractor turns each fence into a candidate `ExtractedCodeBlock`
// the caller (typically Wave 3.1's RawThoughts emitter) can persist
// as a `CodeArtifactSidecar` linked back to the originating Run +
// thought index. This closes the provenance loop the brain dump
// describes: "even when an AI mentions code in raw thoughts, that
// content can be attached."
//
// This module is a pure parser — no FFI, no actors. The output is
// data the caller routes into the unified substrate (Wave 9.5).

/// One fenced code block extracted from chat / raw-thought text.
/// Carries enough provenance metadata to construct a downstream
/// CodeArtifactSidecar without re-scanning the source text.
nonisolated public struct ExtractedCodeBlock: Sendable, Hashable {
    /// CodeArtifactKind inferred from the fence's language tag. Falls
    /// back to `.plain` when the tag is missing or unrecognised.
    public let kind: CodeArtifactKind
    /// Raw fence-language tag as written by the agent (e.g. "swift",
    /// "ts", "py3"). Preserved verbatim because some agents use
    /// non-canonical aliases that the kind classifier collapses.
    public let rawLanguageTag: String
    /// The fence body — text between the opening and closing fence,
    /// trimmed of the leading/trailing newlines that mark the
    /// fence boundaries (but preserved indentation).
    public let body: String
    /// Character offset inside the input text where the OPENING fence
    /// starts. Used by the inspector to highlight the fence in the
    /// chat transcript.
    public let openingFenceOffset: Int

    public init(
        kind: CodeArtifactKind,
        rawLanguageTag: String,
        body: String,
        openingFenceOffset: Int
    ) {
        self.kind = kind
        self.rawLanguageTag = rawLanguageTag
        self.body = body
        self.openingFenceOffset = openingFenceOffset
    }
}

/// Pure markdown-fence parser for agent-mentioned code.
nonisolated public enum ChatCodeExtractor {

    /// Find every triple-backtick fenced code block in the input.
    /// Returns them in source order. Empty array when the input
    /// contains no fences.
    ///
    /// Recognised opening fence forms (case-insensitive language tag):
    ///     ```lang\nCODE\n```
    ///     ```LANG\nCODE\n```
    ///     ```\nCODE\n```          (no language tag → kind .plain)
    ///
    /// Tilde fences (`~~~`) are NOT recognised — they're a CommonMark
    /// alternate that LLMs almost never emit. Add a separate pass if
    /// it ever matters.
    ///
    /// Indented code blocks (4-space) are NOT recognised — they're
    /// indistinguishable from ordinary text indentation in agent
    /// responses and would produce too many false positives.
    public static func extract(from text: String) -> [ExtractedCodeBlock] {
        var results: [ExtractedCodeBlock] = []
        var index = text.startIndex
        var charOffset = 0

        while index < text.endIndex {
            // Find the next opening fence (line starting with ``` ).
            guard let openRange = Self.nextFenceLineRange(in: text, from: index) else {
                break
            }
            // Compute the language tag (everything after ``` to the
            // newline, trimmed).
            let tagStart = text.index(openRange.lowerBound, offsetBy: 3)
            let tagEnd = text[tagStart...].firstIndex(of: "\n") ?? text.endIndex
            let rawTag = String(text[tagStart..<tagEnd])
                .trimmingCharacters(in: .whitespaces)

            // Body starts after the opening line's newline.
            guard tagEnd < text.endIndex else { break }
            let bodyStart = text.index(after: tagEnd)

            // Find the closing fence (the next line that's just ``` ).
            guard let closeRange = Self.nextFenceLineRange(in: text, from: bodyStart) else {
                // Unterminated fence — drop it. Don't try to recover;
                // agents rarely emit unterminated fences and the
                // recovery rules would be ambiguous.
                break
            }

            let body = String(text[bodyStart..<closeRange.lowerBound])
                .trimmingCharacters(in: CharacterSet(charactersIn: "\n"))

            let kind = Self.kind(forLanguageTag: rawTag)
            let openOffset = Self.distance(from: text.startIndex, to: openRange.lowerBound, accumulator: charOffset, in: text)
            charOffset = Self.distance(from: text.startIndex, to: closeRange.upperBound, accumulator: 0, in: text)

            results.append(ExtractedCodeBlock(
                kind: kind,
                rawLanguageTag: rawTag,
                body: body,
                openingFenceOffset: openOffset
            ))

            index = closeRange.upperBound
        }

        return results
    }

    /// Find the next line in `text` that begins with ``` (the fence
    /// marker). Returns the range of the marker itself (3 chars).
    private static func nextFenceLineRange(in text: String, from start: String.Index) -> Range<String.Index>? {
        var probe = start
        // Walk line by line. A fence is recognised when the first
        // three chars of a line are all backticks.
        while probe < text.endIndex {
            let lineStart = probe
            let nextNewline = text[probe...].firstIndex(of: "\n") ?? text.endIndex
            let lineEnd = nextNewline
            // Trim leading whitespace (allow indented fence inside e.g.
            // a quoted reply — agents sometimes prefix their fences
            // with two spaces).
            var contentStart = lineStart
            while contentStart < lineEnd && text[contentStart].isWhitespace && text[contentStart] != "\n" {
                contentStart = text.index(after: contentStart)
            }
            let remaining = text.distance(from: contentStart, to: lineEnd)
            if remaining >= 3 {
                let p1 = contentStart
                let p2 = text.index(after: p1)
                let p3 = text.index(after: p2)
                if text[p1] == "`" && text[p2] == "`" && text[p3] == "`" {
                    return contentStart..<text.index(contentStart, offsetBy: 3)
                }
            }
            probe = nextNewline < text.endIndex ? text.index(after: nextNewline) : text.endIndex
        }
        return nil
    }

    /// Classify a fence's language tag → CodeArtifactKind. Handles
    /// the common LLM aliases: `js`/`javascript`, `ts`/`typescript`,
    /// `py`/`python`, `rb`/`ruby`, `sh`/`bash`/`zsh`/`shell`.
    public static func kind(forLanguageTag tag: String) -> CodeArtifactKind {
        let normalized = tag.lowercased()
        switch normalized {
        case "":                                                     return .plain
        case "swift":                                                return .swift
        case "rust", "rs":                                           return .rust
        case "typescript", "ts", "tsx":                              return .typescript
        case "javascript", "js", "jsx", "mjs", "cjs":                return .javascript
        case "python", "py", "py3":                                  return .python
        case "go", "golang":                                         return .go
        case "ruby", "rb":                                           return .ruby
        case "html", "htm":                                          return .html
        case "css":                                                  return .css
        case "json":                                                 return .json
        case "yaml", "yml":                                          return .yaml
        case "toml":                                                 return .toml
        case "markdown", "md", "mdx":                                return .markdown
        case "shell", "sh", "bash", "zsh":                           return .shell
        case "sql":                                                  return .sql
        default:                                                     return .plain
        }
    }

    private static func distance(from start: String.Index, to end: String.Index, accumulator: Int, in text: String) -> Int {
        accumulator + text.distance(from: start, to: end)
    }
}
