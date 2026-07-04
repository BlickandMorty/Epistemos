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

    static func snapshot(for html: String, source: HTMLWorkspaceDOMSnapshot.Source = .source) -> HTMLWorkspaceDOMSnapshot {
        let tags = tagSummaries(in: html)
        return HTMLWorkspaceDOMSnapshot(
            outline: tags.isEmpty ? "No DOM nodes" : tags.joined(separator: "\n"),
            nodeCount: tags.count,
            source: source
        )
    }

    // HW-DOM-1 (audit 2026-07-04): compiled ONCE like its id/class siblings below — this outer
    // tag-scan regex was rebuilt on every tagSummaries() call, which runs on the main thread on
    // the per-keystroke path (the toolbar reads domNodeCount; each package edit nils
    // liveDOMSnapshot), re-adding the typing lag the siblings were hoisted to fix.
    private static let tagSummaryRegex = try? NSRegularExpression(
        pattern: #"<\s*([A-Za-z][A-Za-z0-9:-]*)([^>]*)>"#)

    private static func tagSummaries(in html: String) -> [String] {
        guard let expression = tagSummaryRegex else { return [] }
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

    // Compiled ONCE (was recompiled per-attribute per-tag → O(tags) regex builds while
    // typing = the HTML-workspace typing lag). Only "id"/"class" are ever passed; the
    // patterns are byte-identical to the old per-call construction. (audit 2026-07-01)
    private static let idAttributeRegex = try? NSRegularExpression(
        pattern: #"id\s*=\s*["']([^"']+)["']"#, options: [.caseInsensitive])
    private static let classAttributeRegex = try? NSRegularExpression(
        pattern: #"class\s*=\s*["']([^"']+)["']"#, options: [.caseInsensitive])

    private static func captureAttribute(_ name: String, in attributes: String) -> String? {
        let expression: NSRegularExpression?
        switch name {
        case "id": expression = idAttributeRegex
        case "class": expression = classAttributeRegex
        default:
            let escapedName = NSRegularExpression.escapedPattern(for: name)
            expression = try? NSRegularExpression(
                pattern: #"\#(escapedName)\s*=\s*["']([^"']+)["']"#,
                options: [.caseInsensitive])
        }
        guard let expression else { return nil }
        let range = NSRange(attributes.startIndex..<attributes.endIndex, in: attributes)
        guard let match = expression.firstMatch(in: attributes, range: range),
              match.numberOfRanges > 1,
              let valueRange = Range(match.range(at: 1), in: attributes) else {
            return nil
        }
        return String(attributes[valueRange])
    }
}
