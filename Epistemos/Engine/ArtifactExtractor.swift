// ArtifactExtractor.swift
//
// Extracts structured artifacts (JSON, YAML, code blocks, tables) from
// assistant response text. Runs after each model response to identify
// rich content that deserves interactive rendering.
//
// Phase 3 of cloud artifact pipeline (2026-04-06).

import Foundation

nonisolated enum ArtifactExtractor {
    // MARK: - Extract from response text

    /// Scan assistant response text for fenced code blocks and markdown tables.
    /// Returns one `Artifact` per block found.
    static func extract(from text: String) -> [Artifact] {
        var artifacts: [Artifact] = []

        // 1. Fenced code blocks: ```lang\n...\n```
        let codeBlockPattern = #"```(\w*)\s*\n([\s\S]*?)```"#
        if let regex = try? NSRegularExpression(pattern: codeBlockPattern) {
            let nsText = text as NSString
            let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
            for match in matches {
                let langRange = match.range(at: 1)
                let contentRange = match.range(at: 2)
                let lang = langRange.location != NSNotFound
                    ? nsText.substring(with: langRange).lowercased()
                    : ""
                let content = contentRange.location != NSNotFound
                    ? nsText.substring(with: contentRange).trimmingCharacters(in: .whitespacesAndNewlines)
                    : ""

                guard !content.isEmpty else { continue }
                // Skip very short blocks (inline snippets, not real artifacts)
                let lines = content.components(separatedBy: .newlines).count
                guard lines >= 3 else { continue }

                let kind: ChatArtifactKind
                let title: String
                switch lang {
                case "json":
                    kind = .json
                    title = titleFromContext(text: text, matchRange: match.range) ?? "JSON Output"
                case "yaml", "yml":
                    kind = .yaml
                    title = titleFromContext(text: text, matchRange: match.range) ?? "YAML Output"
                case "csv":
                    kind = .csv
                    title = titleFromContext(text: text, matchRange: match.range) ?? "CSV Data"
                default:
                    kind = .codeBlock
                    title = titleFromContext(text: text, matchRange: match.range)
                        ?? (lang.isEmpty ? "Code" : "\(lang.capitalized) Code")
                }

                artifacts.append(Artifact(
                    kind: kind,
                    title: title,
                    language: lang.isEmpty ? nil : lang,
                    content: content
                ))
            }
        }

        // 2. Markdown tables: consecutive lines starting with |
        let tablePattern = #"(?:^|\n)(\|[^\n]+\|\n\|[-| :]+\|\n(?:\|[^\n]+\|\n?)+)"#
        if let regex = try? NSRegularExpression(pattern: tablePattern) {
            let nsText = text as NSString
            let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
            for match in matches {
                let tableText = nsText.substring(with: match.range(at: 1))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard !tableText.isEmpty else { continue }
                let rows = tableText.components(separatedBy: .newlines).count
                guard rows >= 3 else { continue } // header + separator + at least 1 data row

                artifacts.append(Artifact(
                    kind: .table,
                    title: titleFromContext(text: text, matchRange: match.range) ?? "Table",
                    content: tableText
                ))
            }
        }

        return artifacts
    }

    // MARK: - From structured result

    /// Wrap a `StructuredGenerationResult.rawJSON` into an artifact.
    static func fromStructuredResult(
        rawJSON: String,
        title: String = "Structured Output",
        schemaName: String? = nil
    ) -> Artifact {
        // Pretty-print if possible
        let prettyJSON: String
        if let data = rawJSON.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: data),
           let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
           let str = String(data: pretty, encoding: .utf8) {
            prettyJSON = str
        } else {
            prettyJSON = rawJSON
        }

        return Artifact(
            kind: .json,
            title: title,
            language: "json",
            content: prettyJSON,
            schemaName: schemaName
        )
    }

    // MARK: - Helpers

    /// Try to extract a title from the line immediately preceding a code block.
    /// If the preceding line looks like a heading or label, use it.
    private static func titleFromContext(text: String, matchRange: NSRange) -> String? {
        let nsText = text as NSString
        guard matchRange.location > 1 else { return nil }

        // Find the line before the match
        let beforeRange = NSRange(location: 0, length: matchRange.location)
        let beforeText = nsText.substring(with: beforeRange)
        let lines = beforeText.components(separatedBy: .newlines)
        guard let lastLine = lines.last(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) else {
            return nil
        }

        let trimmed = lastLine.trimmingCharacters(in: .whitespaces)
        // Strip markdown heading markers
        let cleaned = trimmed.replacingOccurrences(of: "^#{1,4}\\s*", with: "", options: .regularExpression)
        // Strip trailing colons
        let final = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: ":"))
            .trimmingCharacters(in: .whitespaces)

        // Only use if it's short enough to be a title (not a full sentence)
        guard final.count >= 2, final.count <= 80 else { return nil }
        // Skip if it looks like a sentence (contains multiple spaces + period)
        if final.contains(". ") && final.count > 40 { return nil }

        return final
    }
}
