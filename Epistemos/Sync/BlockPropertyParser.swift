import Foundation

// MARK: - BlockPropertyParser
// Parses trailing @key=value properties from block lines.
// Stateless — all methods are static. Used by MarkdownTextStorage (chip styling)
// and BlockPropertySheet (user edits).

enum BlockPropertyParser {

    // Pre-compiled regex: @word=non-whitespace-non-@ value
    private static let pattern = try! NSRegularExpression(pattern: #"@(\w+)=([^\s@]+)"#)

    /// Parse trailing @key=value properties from the end of a line.
    /// Only captures properties at the end — ignores mid-sentence @mentions.
    static func parse(_ line: String) -> [String: PropertyValue] {
        guard !line.isEmpty else { return [:] }

        let nsLine = line as NSString
        let fullRange = NSRange(location: 0, length: nsLine.length)
        let matches = pattern.matches(in: line, range: fullRange)
        guard !matches.isEmpty else { return [:] }

        // Only trailing properties: find the rightmost contiguous group of @key=value
        // that extends to the end of the line (ignoring trailing whitespace).
        let trimmedEnd = nsLine.length - (line.reversed().prefix(while: { $0.isWhitespace }).count)

        // Walk backward from trimmedEnd to find the start of the trailing property block
        var trailingStart = trimmedEnd
        for match in matches.reversed() {
            let matchEnd = match.range.location + match.range.length
            // Match must touch (or be separated by whitespace from) the current trailing block start
            if matchEnd == trailingStart || (matchEnd < trailingStart &&
                nsLine.substring(with: NSRange(location: matchEnd, length: trailingStart - matchEnd))
                    .allSatisfy({ $0.isWhitespace })) {
                trailingStart = match.range.location
            } else {
                break
            }
        }

        var result: [String: PropertyValue] = [:]
        for match in matches where match.range.location >= trailingStart {
            let key = nsLine.substring(with: match.range(at: 1))
            let raw = nsLine.substring(with: match.range(at: 2))
            result[key] = parseValue(raw)
        }
        return result
    }

    /// Parse a raw string value into the most specific PropertyValue type.
    /// Priority: Int (if whole number) → Float → Bool → String
    static func parseValue(_ raw: String) -> PropertyValue {
        // Bool
        if raw.lowercased() == "true" { return .bool(true) }
        if raw.lowercased() == "false" { return .bool(false) }

        // Numeric — try Float first (covers both int and float syntax)
        if let f = Float(raw) {
            // If it's a whole number with no decimal point, prefer Int
            if !raw.contains("."), let i = Int(raw) {
                return .int(i)
            }
            return .float(f)
        }

        return .string(raw)
    }
}
