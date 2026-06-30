import Foundation

nonisolated struct HTMLWorkspaceDOMSnapshot: Equatable, Sendable {
    enum Source: String, Sendable {
        case source
        case live

        var label: String {
            switch self {
            case .source: "source"
            case .live: "live"
            }
        }
    }

    var outline: String
    var nodeCount: Int
    var source: Source
}

nonisolated enum HTMLWorkspaceDOMOutline {
    static func outline(for html: String) -> String {
        let tags = tagSummaries(in: html)
        guard !tags.isEmpty else { return "No DOM nodes" }
        return tags.joined(separator: "\n")
    }

    static func nodeCount(in html: String) -> Int {
        tagSummaries(in: html).count
    }

    static func snapshot(for html: String, source: HTMLWorkspaceDOMSnapshot.Source = .source) -> HTMLWorkspaceDOMSnapshot {
        let tags = tagSummaries(in: html)
        return HTMLWorkspaceDOMSnapshot(
            outline: tags.isEmpty ? "No DOM nodes" : tags.joined(separator: "\n"),
            nodeCount: tags.count,
            source: source
        )
    }

    private static func tagSummaries(in html: String) -> [String] {
        guard let expression = try? NSRegularExpression(
            pattern: #"<\s*([A-Za-z][A-Za-z0-9:-]*)([^>]*)>"#
        ) else { return [] }
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        let matches = expression.matches(in: html, range: range)
        return matches.compactMap { match in
            guard let tagRange = Range(match.range(at: 1), in: html) else { return nil }
            let tag = String(html[tagRange]).lowercased()
            guard !tag.hasPrefix("!") else { return nil }
            let attributes = match.range(at: 2).location == NSNotFound
                ? ""
                : Range(match.range(at: 2), in: html).map { String(html[$0]) } ?? ""
            let id = captureAttribute("id", in: attributes).map { "#\($0)" } ?? ""
            let classes = captureAttribute("class", in: attributes)
                .map { "." + $0.split(separator: " ").joined(separator: ".") } ?? ""
            let dataMarker = attributes.contains("data-") ? " data" : ""
            return "<\(tag)\(id)\(classes)>\(dataMarker)"
        }
    }

    private static func captureAttribute(_ name: String, in attributes: String) -> String? {
        let escapedName = NSRegularExpression.escapedPattern(for: name)
        guard let expression = try? NSRegularExpression(
            pattern: #"\#(escapedName)\s*=\s*["']([^"']+)["']"#,
            options: [.caseInsensitive]
        ) else { return nil }
        let range = NSRange(attributes.startIndex..<attributes.endIndex, in: attributes)
        guard let match = expression.firstMatch(in: attributes, range: range),
              match.numberOfRanges > 1,
              let valueRange = Range(match.range(at: 1), in: attributes) else {
            return nil
        }
        return String(attributes[valueRange])
    }
}
