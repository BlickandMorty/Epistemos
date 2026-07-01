import AppKit
import Foundation

struct WebClipCaptureDraft: Equatable, Sendable {
    var title: String
    var sourceURL: String
    var html: String
    var plainText: String
    var capturedAt: Date
}

struct WebClipMarkdownDocument: Equatable, Sendable {
    var title: String
    var markdownBody: String
    var frontMatter: [String: String]
}

enum WebClipperCreationError: LocalizedError, Equatable {
    case emptyCapture
    case vaultUnavailable

    var errorDescription: String? {
        switch self {
        case .emptyCapture:
            "Paste page HTML or readable text before creating the clip."
        case .vaultUnavailable:
            "No active vault is available for the web clip."
        }
    }
}

enum WebClipperMarkdownBuilder {
    static let maxHTMLCharacters = 750_000
    static let maxTextCharacters = 350_000
    static let maxTitleCharacters = 120
    static let maxSourceURLCharacters = 2_048

    static func document(from draft: WebClipCaptureDraft) throws -> WebClipMarkdownDocument {
        let sourceURL = normalizedSourceURL(draft.sourceURL)
        let bodyText = canonicalBodyText(html: draft.html, plainText: draft.plainText)
        guard !bodyText.isEmpty else {
            throw WebClipperCreationError.emptyCapture
        }

        let resolvedTitle = title(
            userTitle: draft.title,
            html: draft.html,
            sourceURL: sourceURL
        )
        return WebClipMarkdownDocument(
            title: resolvedTitle,
            markdownBody: markdownBody(
                bodyText: bodyText,
                sourceURL: sourceURL
            ),
            frontMatter: frontMatter(
                sourceURL: sourceURL,
                title: resolvedTitle,
                capturedAt: draft.capturedAt
            )
        )
    }

    private static func frontMatter(
        sourceURL: String?,
        title: String,
        capturedAt: Date
    ) -> [String: String] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        var values: [String: String] = [
            "source": "web",
            "source_kind": "web_clip",
            "captured_at": formatter.string(from: capturedAt),
            "source_title": title,
        ]
        if let sourceURL {
            values["source-url"] = sourceURL
        }
        return values
    }

    private static func markdownBody(bodyText: String, sourceURL: String?) -> String {
        var lines: [String] = []
        if let sourceURL {
            lines.append("Source: <\(sourceURL)>")
            lines.append("")
        }
        lines.append(bodyText)
        return lines.joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func title(
        userTitle: String,
        html: String,
        sourceURL: String?
    ) -> String {
        let candidates = [
            userTitle,
            extractedHTMLTitle(html, tagName: "title"),
            extractedHTMLTitle(html, tagName: "h1"),
            sourceURL.flatMap { URL(string: $0)?.host } ?? "",
            "Web Clip",
        ]

        for candidate in candidates {
            let cleaned = normalizePlainText(candidate)
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleaned.isEmpty {
                return String(cleaned.prefix(maxTitleCharacters))
            }
        }
        return "Web Clip"
    }

    private static func canonicalBodyText(html: String, plainText: String) -> String {
        let boundedHTML = bounded(html, limit: maxHTMLCharacters)
        if looksLikeHTML(boundedHTML) {
            let converted = markdownText(fromHTML: boundedHTML)
            if !converted.isEmpty {
                return converted
            }
        }
        let fallback = plainText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? boundedHTML
            : bounded(plainText, limit: maxTextCharacters)
        return normalizePlainText(fallback)
    }

    private static func markdownText(fromHTML html: String) -> String {
        let sanitized = stripUnsafeHTML(from: html)
        guard let data = sanitized.data(using: .utf8) else {
            return normalizePlainText(stripTags(from: sanitized))
        }

        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue,
        ]

        if let attributed = try? NSAttributedString(
            data: data,
            options: options,
            documentAttributes: nil
        ) {
            return normalizePlainText(markdownText(from: attributed))
        }
        return normalizePlainText(stripTags(from: sanitized))
    }

    private static func markdownText(from attributed: NSAttributedString) -> String {
        let string = attributed.string as NSString
        guard string.length > 0 else { return "" }

        var output = ""
        var cursor = 0
        let fullRange = NSRange(location: 0, length: string.length)
        attributed.enumerateAttribute(.link, in: fullRange) { value, range, _ in
            guard range.location >= cursor else { return }
            if range.location > cursor {
                output += string.substring(
                    with: NSRange(location: cursor, length: range.location - cursor)
                )
            }

            let text = string.substring(with: range)
            if let href = markdownLinkDestination(from: value),
               !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                output += "[\(markdownEscapedLinkText(text))](\(href))"
            } else {
                output += text
            }
            cursor = range.location + range.length
        }

        if cursor < string.length {
            output += string.substring(
                with: NSRange(location: cursor, length: string.length - cursor)
            )
        }
        return output
    }

    private static func markdownLinkDestination(from value: Any?) -> String? {
        let raw: String?
        switch value {
        case let url as URL:
            raw = url.absoluteString
        case let url as NSURL:
            raw = url.absoluteString
        case let string as String:
            raw = string
        default:
            raw = nil
        }

        guard let raw else { return nil }
        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }

        let lower = cleaned.lowercased()
        if lower.hasPrefix("javascript:")
            || lower.hasPrefix("data:")
            || lower.hasPrefix("file:")
            || lower.hasPrefix("blob:")
        {
            return nil
        }
        if lower.contains("://"),
           !(lower.hasPrefix("http://") || lower.hasPrefix("https://")) {
            return nil
        }
        return markdownEscapedLinkDestination(cleaned)
    }

    private static func markdownEscapedLinkText(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "[", with: "\\[")
            .replacingOccurrences(of: "]", with: "\\]")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func markdownEscapedLinkDestination(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ">", with: "%3E")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
        if escaped.rangeOfCharacter(from: .whitespacesAndNewlines) != nil
            || escaped.contains("(")
            || escaped.contains(")")
        {
            return "<\(escaped)>"
        }
        return escaped
    }

    private static func stripUnsafeHTML(from html: String) -> String {
        var output = html
        let unsafeBlockPattern = #"(?is)<(script|style|noscript|template|iframe|object|embed|svg|canvas)\b[^>]*>.*?</\1\s*>"#
        output = replacingMatches(in: output, pattern: unsafeBlockPattern, with: " ")
        output = replacingMatches(in: output, pattern: #"(?is)<!--.*?-->"#, with: " ")
        return output
    }

    private static func stripTags(from html: String) -> String {
        replacingMatches(in: html, pattern: #"(?is)<[^>]+>"#, with: " ")
    }

    private static func extractedHTMLTitle(_ html: String, tagName: String) -> String {
        let boundedHTML = bounded(html, limit: maxHTMLCharacters)
        let pattern = #"(?is)<\#(tagName)\b[^>]*>(.*?)</\#(tagName)\s*>"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return "" }
        let range = NSRange(boundedHTML.startIndex..<boundedHTML.endIndex, in: boundedHTML)
        guard let match = regex.firstMatch(in: boundedHTML, range: range),
              match.numberOfRanges > 2,
              let captureRange = Range(match.range(at: 2), in: boundedHTML)
        else {
            return ""
        }
        return markdownText(fromHTML: String(boundedHTML[captureRange]))
    }

    static func normalizedSourceURL(_ rawURL: String) -> String? {
        let cleaned = rawURL
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }
        guard cleaned.count <= maxSourceURLCharacters else { return nil }
        guard let components = URLComponents(string: cleaned),
              let scheme = components.scheme?.lowercased(),
              (scheme == "http" || scheme == "https"),
              components.host?.isEmpty == false else {
            return nil
        }
        return cleaned
    }

    private static func looksLikeHTML(_ value: String) -> Bool {
        let pattern = #"(?is)</?[a-z][a-z0-9-]*(\s[^>]*)?>"#
        return value.range(of: pattern, options: .regularExpression) != nil
    }

    private static func normalizePlainText(_ value: String) -> String {
        let normalizedNewlines = value
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\u{00A0}", with: " ")

        var lines: [String] = []
        var previousWasBlank = false
        for rawLine in normalizedNewlines.components(separatedBy: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty {
                if !previousWasBlank, !lines.isEmpty {
                    lines.append("")
                }
                previousWasBlank = true
            } else {
                lines.append(line)
                previousWasBlank = false
            }
        }
        return lines.joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func replacingMatches(
        in value: String,
        pattern: String,
        with replacement: String
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return value }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return regex.stringByReplacingMatches(
            in: value,
            range: range,
            withTemplate: replacement
        )
    }

    private static func bounded(_ value: String, limit: Int) -> String {
        guard value.count > limit else { return value }
        return String(value.prefix(limit))
    }
}
