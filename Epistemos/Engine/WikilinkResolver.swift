import Foundation

enum WikilinkResolver {
    private nonisolated static let markdownExtensions: Set<String> = ["md", "markdown", "txt"]

    nonisolated static func isLikelyMarkdownNote(path: String?) -> Bool {
        guard let path, !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return true
        }
        let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
        return markdownExtensions.contains(ext)
    }

    nonisolated static func extractDestinations(from text: String) -> [String] {
        guard text.contains("[[") || text.contains("](") else { return [] }

        var candidates: [DestinationCandidate] = []
        var destinations: [String] = []
        var seen = Set<String>()
        appendWikilinkDestinations(from: text, to: &candidates)
        appendMarkdownLinkDestinations(from: text, to: &candidates)

        candidates.sort { $0.position < $1.position }

        for candidate in candidates where seen.insert(candidate.destination).inserted {
            destinations.append(candidate.destination)
        }

        return destinations
    }

    private struct DestinationCandidate {
        let position: String.Index
        let destination: String
    }

    private nonisolated static func appendWikilinkDestinations(
        from text: String,
        to candidates: inout [DestinationCandidate]
    ) {
        var searchStart = text.startIndex

        while searchStart < text.endIndex,
              let open = text.range(of: "[[", range: searchStart..<text.endIndex) {
            let candidateStart = open.upperBound
            guard let close = text.range(of: "]]", range: candidateStart..<text.endIndex) else {
                break
            }

            let raw = String(text[candidateStart..<close.lowerBound])
            if let destination = canonicalDestination(raw) {
                candidates.append(DestinationCandidate(position: open.lowerBound, destination: destination))
            }

            searchStart = close.upperBound
        }
    }

    private nonisolated static func appendMarkdownLinkDestinations(
        from text: String,
        to candidates: inout [DestinationCandidate]
    ) {
        var searchStart = text.startIndex

        while searchStart < text.endIndex,
              let delimiter = text.range(of: "](", range: searchStart..<text.endIndex) {
            let labelRange = text[..<delimiter.lowerBound]
            guard let openBracket = labelRange.lastIndex(of: "[") else {
                searchStart = delimiter.upperBound
                continue
            }

            if openBracket > text.startIndex {
                let previous = text.index(before: openBracket)
                if text[previous] == "!" {
                    searchStart = delimiter.upperBound
                    continue
                }
            }

            let destinationStart = delimiter.upperBound
            guard let closeParen = text[destinationStart...].firstIndex(of: ")") else {
                break
            }

            let raw = String(text[destinationStart..<closeParen])
            if let destination = canonicalMarkdownDestination(raw) {
                candidates.append(DestinationCandidate(position: openBracket, destination: destination))
            }

            searchStart = text.index(after: closeParen)
        }
    }

    private nonisolated static func canonicalMarkdownDestination(_ raw: String) -> String? {
        var destination = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if destination.hasPrefix("<"), destination.hasSuffix(">"), destination.count > 2 {
            destination.removeFirst()
            destination.removeLast()
            destination = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard !destination.isEmpty, !destination.hasPrefix("#") else { return nil }

        let lower = destination.lowercased()
        let externalSchemes = [
            "http:", "https:", "mailto:", "data:", "javascript:", "obsidian:",
            "x-devonthink-item:", "bear:", "hook:", "ftp:"
        ]
        if lower.contains("://") || externalSchemes.contains(where: lower.hasPrefix) {
            return nil
        }

        let withoutFragment = destination.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
            .first
            .map(String.init) ?? destination
        let withoutQuery = withoutFragment.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
            .first
            .map(String.init) ?? withoutFragment
        let decoded = withoutQuery.removingPercentEncoding ?? withoutQuery
        let ext = URL(fileURLWithPath: decoded).pathExtension.lowercased()
        guard ext.isEmpty || markdownExtensions.contains(ext) else { return nil }

        return canonicalDestination(withoutQuery)
    }

    nonisolated static func canonicalDestination(_ raw: String) -> String? {
        let withoutAlias = raw.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
            .first
            .map(String.init) ?? raw
        let withoutBlock = withoutAlias.split(separator: "^", maxSplits: 1, omittingEmptySubsequences: false)
            .first
            .map(String.init) ?? withoutAlias
        let withoutHeading = withoutBlock.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
            .first
            .map(String.init) ?? withoutBlock

        let decoded = withoutHeading.removingPercentEncoding ?? withoutHeading
        let normalized = normalizeLookupKey(decoded)
        return normalized.isEmpty ? nil : normalized
    }

    nonisolated static func destinationMatches(_ destination: String, targetKeys: Set<String>) -> Bool {
        lookupKeys(forDestination: destination).contains { targetKeys.contains($0) }
    }

    nonisolated static func lookupKeys(forDestination destination: String) -> [String] {
        var keys: [String] = []
        appendKey(normalizeLookupKey(destination), to: &keys)

        let basename = URL(fileURLWithPath: destination).deletingPathExtension().lastPathComponent
        appendKey(normalizeLookupKey(basename), to: &keys)

        return keys
    }

    nonisolated static func lookupKeysForPage(title: String, filePath: String?, vaultRelativePath: String? = nil) -> [String] {
        var keys: [String] = []
        appendKey(normalizeLookupKey(title), to: &keys)
        appendPathKeys(vaultRelativePath, to: &keys)

        if let filePath {
            let url = URL(fileURLWithPath: filePath)
            appendKey(normalizeLookupKey(url.deletingPathExtension().lastPathComponent), to: &keys)

            let components = url.deletingPathExtension().pathComponents.filter { component in
                component != "/" && component != "."
            }
            if components.count > 1 {
                for start in 0..<(components.count - 1) {
                    appendKey(normalizeLookupKey(components[start...].joined(separator: "/")), to: &keys)
                }
            }
        }

        return keys
    }

    private nonisolated static func appendPathKeys(_ path: String?, to keys: inout [String]) {
        guard let path else { return }
        let normalized = normalizeLookupKey(path)
        appendKey(normalized, to: &keys)

        let parts = normalized.split(separator: "/").map(String.init)
        if parts.count > 1 {
            appendKey(parts.last ?? "", to: &keys)
            for start in 0..<(parts.count - 1) {
                appendKey(parts[start...].joined(separator: "/"), to: &keys)
            }
        }
    }

    private nonisolated static func appendKey(_ key: String, to keys: inout [String]) {
        guard !key.isEmpty, !keys.contains(key) else { return }
        keys.append(key)
    }

    private nonisolated static func normalizeLookupKey(_ value: String) -> String {
        var text = value
            .replacingOccurrences(of: "\\", with: "/")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        while text.contains("//") {
            text = text.replacingOccurrences(of: "//", with: "/")
        }
        text = text.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        let lower = text.lowercased()
        if lower.hasSuffix(".md") {
            text = String(text.dropLast(3))
        } else if lower.hasSuffix(".markdown") {
            text = String(text.dropLast(9))
        }

        return text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}
