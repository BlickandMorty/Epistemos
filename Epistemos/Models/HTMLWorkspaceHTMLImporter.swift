import Foundation

nonisolated enum HTMLWorkspaceHTMLImporter {
    struct ImportedSources {
        var html: String
        var css: String
        var js: String
        var dataJSON: String
    }

    private static let generatedStyleIDs: Set<String> = [
        "epistemos-font-face",
        "epistemos-theme-guard",
        "epistemos-theme-host",
    ]
    private static let generatedScriptIDs: Set<String> = [
        "epistemos-workspace-runtime",
    ]

    static func importSources(from source: String) -> ImportedSources {
        let dataJSON = firstCapture(
            pattern: #"(?is)<script[^>]*id\s*=\s*["']workspace-data["'][^>]*>(.*?)</script>"#,
            in: source
        ).map(decodeScriptData) ?? ""
        let css = styleBodies(in: source).joined(separator: "\n\n")
        let js = scriptBodies(in: source).joined(separator: "\n\n")

        let rawBody = firstCapture(pattern: #"(?is)<body[^>]*>(.*?)</body>"#, in: source) ?? source
        let cleanedBody = rawBody
            .replacingOccurrences(
                of: #"(?is)<script[^>]*>.*?</script>"#,
                with: "",
                options: [.regularExpression]
            )
            .replacingOccurrences(
                of: #"(?is)<style[^>]*>.*?</style>"#,
                with: "",
                options: [.regularExpression]
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return ImportedSources(
            html: cleanedBody.isEmpty ? "<main></main>" : cleanedBody,
            css: css,
            js: js,
            dataJSON: dataJSON
        )
    }

    private static func captures(pattern: String, in source: String) -> [String] {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(source.startIndex..<source.endIndex, in: source)
        return expression.matches(in: source, range: range).compactMap { match in
            guard let captureRange = Range(match.range(at: 1), in: source) else { return nil }
            return String(source[captureRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private static func firstCapture(pattern: String, in source: String) -> String? {
        captures(pattern: pattern, in: source).first
    }

    private static func styleBodies(in source: String) -> [String] {
        guard let expression = try? NSRegularExpression(pattern: #"(?is)<style\b([^>]*)>(.*?)</style>"#) else {
            return []
        }
        let range = NSRange(source.startIndex..<source.endIndex, in: source)
        return expression.matches(in: source, range: range).compactMap { match in
            guard let attributesRange = Range(match.range(at: 1), in: source),
                  let bodyRange = Range(match.range(at: 2), in: source) else { return nil }
            let attributes = String(source[attributesRange])
            if let styleID = capturedID(in: attributes)?.lowercased(), generatedStyleIDs.contains(styleID) {
                return nil
            }
            return String(source[bodyRange])
        }
    }

    private static func scriptBodies(in source: String) -> [String] {
        guard let expression = try? NSRegularExpression(pattern: #"(?is)<script\b([^>]*)>(.*?)</script>"#) else {
            return []
        }
        let range = NSRange(source.startIndex..<source.endIndex, in: source)
        return expression.matches(in: source, range: range).compactMap { match in
            guard let attributesRange = Range(match.range(at: 1), in: source),
                  let bodyRange = Range(match.range(at: 2), in: source) else { return nil }
            let attributes = String(source[attributesRange])
            if !shouldImportScript(type: capturedAttribute("type", in: attributes)) {
                return nil
            }
            if let scriptID = capturedID(in: attributes)?.lowercased(),
               generatedScriptIDs.contains(scriptID) || scriptID == "workspace-data" {
                return nil
            }
            let body = String(source[bodyRange])
            if body.contains("Object.defineProperty(window, 'HTMLWorkspace'") {
                return nil
            }
            return body
        }
    }

    private static func shouldImportScript(type rawType: String?) -> Bool {
        guard let rawType else { return true }
        let normalized = rawType
            .split(separator: ";", maxSplits: 1, omittingEmptySubsequences: false)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
        guard !normalized.isEmpty else { return true }
        return normalized == "module"
            || normalized == "text/javascript"
            || normalized == "application/javascript"
            || normalized == "text/ecmascript"
            || normalized == "application/ecmascript"
    }

    private static func capturedID(in attributes: String) -> String? {
        capturedAttribute("id", in: attributes)
    }

    private static func capturedAttribute(_ name: String, in attributes: String) -> String? {
        let escapedName = NSRegularExpression.escapedPattern(for: name)
        guard let expression = try? NSRegularExpression(pattern: #"(?is)\b\#(escapedName)\s*=\s*["']([^"']+)["']"#) else {
            return nil
        }
        let range = NSRange(attributes.startIndex..<attributes.endIndex, in: attributes)
        guard let match = expression.firstMatch(in: attributes, range: range),
              let idRange = Range(match.range(at: 1), in: attributes) else {
            return nil
        }
        return String(attributes[idRange])
    }

    private static func decodeBasicHTMLEntities(_ source: String) -> String {
        source
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")
    }

    private static func decodeScriptData(_ source: String) -> String {
        decodeBasicHTMLEntities(source)
            .replacingOccurrences(of: #"<\/script"#, with: "</script", options: [.caseInsensitive])
            .replacingOccurrences(of: #"<\!--"#, with: "<!--")
    }
}
