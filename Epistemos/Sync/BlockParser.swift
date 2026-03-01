import Foundation

// MARK: - BlockParser
// Pure function module for bidirectional conversion between markdown text and block structure.
// No SwiftData dependency — operates on strings and value types only.
//
// Parsing rules:
//   - Lines starting with `- `, `* `, or ordered list markers (`1. `) are list-item blocks.
//     Their leading whitespace determines depth (each tab or 2 spaces = +1 depth).
//   - Non-list paragraphs (separated by blank lines) are blocks at depth 0.
//   - Headings (`# `, `## `, etc.) are blocks at depth 0.
//   - Fenced code blocks (``` ... ```) are treated as a single block.
//   - Blockquotes (`> `) preserve their markers in content.
//   - Blank lines are not blocks — they serve as paragraph separators.
//
// Performance: O(n) single-pass parsing where n = character count.

enum BlockParser {

    struct ParsedBlock: Equatable {
        /// The text content of the block (without leading indent/list markers).
        let content: String
        /// The raw line text including markers (for serialization roundtrip).
        let rawContent: String
        /// Indentation depth (0 = top-level).
        let depth: Int
        /// Sequential position among all blocks in the document.
        let order: Int
        /// Byte range in the original markdown for O(1) mapping back to source.
        let utf16Range: Range<Int>
    }

    // MARK: - Parse

    /// Parse markdown into a flat, ordered list of blocks.
    static func parse(_ markdown: String) -> [ParsedBlock] {
        guard !markdown.isEmpty else { return [] }

        let lines = markdown.split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)

        let maxUtf16 = markdown.utf16.count
        var blocks: [ParsedBlock] = []
        var blockOrder = 0
        var lineIndex = 0
        var utf16Offset = 0

        while lineIndex < lines.count {
            let line = lines[lineIndex]
            let lineUtf16Count = line.utf16.count

            // Skip blank lines (paragraph separators)
            if line.allSatisfy({ $0.isWhitespace }) {
                utf16Offset += lineUtf16Count + 1 // +1 for \n
                lineIndex += 1
                continue
            }

            // Fenced code block: consume until closing fence
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") {
                let fenceStart = utf16Offset
                var fenceContent = line
                lineIndex += 1
                utf16Offset += lineUtf16Count + 1

                while lineIndex < lines.count {
                    let fenceLine = lines[lineIndex]
                    let fenceLineUtf16 = fenceLine.utf16.count
                    fenceContent += "\n" + fenceLine
                    lineIndex += 1
                    utf16Offset += fenceLineUtf16 + 1

                    if fenceLine.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                        break
                    }
                }

                blocks.append(ParsedBlock(
                    content: fenceContent,
                    rawContent: fenceContent,
                    depth: 0,
                    order: blockOrder,
                    utf16Range: fenceStart..<min(utf16Offset - 1, maxUtf16)
                ))
                blockOrder += 1
                continue
            }

            // Determine indent depth and content
            let (depth, stripped) = measureIndent(line)

            // Check for list item markers
            let (isListItem, contentAfterMarker) = stripListMarker(stripped)

            let content = isListItem ? contentAfterMarker : stripped

            // For non-list, non-heading lines: accumulate continuation lines
            // (lines that follow without a blank line and aren't list items/headings)
            let isHeading = stripped.hasPrefix("#")
            var fullContent = content
            var fullRaw = line
            let startUtf16 = utf16Offset
            utf16Offset += lineUtf16Count + 1
            lineIndex += 1

            if !isListItem && !isHeading {
                // Paragraph: accumulate continuation lines
                while lineIndex < lines.count {
                    let nextLine = lines[lineIndex]
                    let nextTrimmed = nextLine.trimmingCharacters(in: .whitespaces)

                    // Stop on blank line, list item, heading, or fence
                    if nextTrimmed.isEmpty { break }
                    if nextTrimmed.hasPrefix("```") { break }
                    if nextTrimmed.hasPrefix("#") { break }

                    let (_, nextStripped) = measureIndent(nextLine)
                    let (nextIsList, _) = stripListMarker(nextStripped)
                    if nextIsList { break }

                    let nextUtf16 = nextLine.utf16.count
                    fullContent += "\n" + nextLine
                    fullRaw += "\n" + nextLine
                    utf16Offset += nextUtf16 + 1
                    lineIndex += 1
                }
            } else if isListItem {
                // List item: accumulate indented continuation lines
                while lineIndex < lines.count {
                    let nextLine = lines[lineIndex]
                    let nextTrimmed = nextLine.trimmingCharacters(in: .whitespaces)

                    if nextTrimmed.isEmpty { break }
                    if nextTrimmed.hasPrefix("```") { break }

                    let (nextDepth, nextStripped) = measureIndent(nextLine)
                    let (nextIsList, _) = stripListMarker(nextStripped)

                    // Only accumulate if deeper indent and not a new list item
                    if nextDepth <= depth || nextIsList { break }

                    let nextUtf16 = nextLine.utf16.count
                    fullContent += "\n" + nextLine.trimmingCharacters(in: .init(charactersIn: "\t "))
                    fullRaw += "\n" + nextLine
                    utf16Offset += nextUtf16 + 1
                    lineIndex += 1
                }
            }

            blocks.append(ParsedBlock(
                content: fullContent,
                rawContent: fullRaw,
                depth: depth,
                order: blockOrder,
                utf16Range: startUtf16..<min(utf16Offset - 1, maxUtf16)
            ))
            blockOrder += 1
        }

        return blocks
    }

    // MARK: - Serialize

    /// Serialize a list of parsed blocks back to markdown.
    /// Inverse of parse() — each block's depth determines indentation.
    static func serialize(_ blocks: [ParsedBlock]) -> String {
        var result = ""
        for (i, block) in blocks.enumerated() {
            if i > 0 { result += "\n" }
            result += block.rawContent
        }
        return result
    }

    // MARK: - Private Helpers

    /// Measure indent depth: each tab = +1, each 2 spaces = +1.
    /// Returns (depth, string with leading whitespace removed).
    private static func measureIndent(_ line: String) -> (Int, String) {
        var depth = 0
        var idx = line.startIndex
        var spaceCount = 0

        while idx < line.endIndex {
            let ch = line[idx]
            if ch == "\t" {
                depth += 1
                spaceCount = 0
            } else if ch == " " {
                spaceCount += 1
                if spaceCount == 2 {
                    depth += 1
                    spaceCount = 0
                }
            } else {
                break
            }
            line.formIndex(after: &idx)
        }

        return (depth, String(line[idx...]))
    }

    /// Strip list item marker (`- `, `* `, `1. `, etc.) from the start of a string.
    /// Returns (isListItem, contentAfterMarker).
    private static func stripListMarker(_ s: String) -> (Bool, String) {
        // Unordered: "- " or "* "
        if s.hasPrefix("- ") { return (true, String(s.dropFirst(2))) }
        if s.hasPrefix("* ") { return (true, String(s.dropFirst(2))) }

        // Ordered: "1. ", "2. ", "10. ", etc.
        var i = s.startIndex
        while i < s.endIndex, s[i].isNumber {
            s.formIndex(after: &i)
        }
        if i != s.startIndex, i < s.endIndex, s[i] == "." {
            let afterDot = s.index(after: i)
            if afterDot < s.endIndex, s[afterDot] == " " {
                return (true, String(s[s.index(after: afterDot)...]))
            }
        }

        return (false, s)
    }
}
