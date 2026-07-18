import Foundation

nonisolated struct EpdocNotebookManifest: Equatable, Sendable {
    static let bodyTabID = "epdoc-notebook-body"
    static let fenceInfoString = "epistemos-notebook"
    static let frontmatterKey = "_epistemos_notebook"
    private static let manifestScanLimitUTF16 = 65_536

    let tabs: [EpdocNotebookTab]
    let source: Source

    enum Source: Equatable, Sendable {
        case none
        case fenced(startLine: Int, charOffset: Int)
        case frontmatter(startLine: Int, charOffset: Int)
    }

    static func normalizedFreeV1SelectedTabID(_ selectedTabID: String) -> String {
        guard selectedTabID == bodyTabID else { return bodyTabID }
        return bodyTabID
    }

    nonisolated static func parse(in markdown: String) -> EpdocNotebookManifest {
        if let fenced = parseFencedManifest(in: markdown) {
            return fenced
        }
        if let frontmatter = parseFrontmatterManifest(in: markdown) {
            return frontmatter
        }
        return EpdocNotebookManifest(tabs: [], source: .none)
    }

    nonisolated static func renderedManifestBlock(tabs: [EpdocNotebookTab], lineEnding: String = "\n") -> String {
        var lines = ["version: 1"]
        for tab in tabs {
            guard tab.kind != .body else { continue }
            lines.append(tab.manifestLine)
        }
        return lines.joined(separator: lineEnding)
    }

    nonisolated static func renderedFencedManifest(tabs: [EpdocNotebookTab], lineEnding: String = "\n") -> String {
        [
            "```\(Self.fenceInfoString)",
            renderedManifestBlock(tabs: tabs, lineEnding: lineEnding),
            "```",
        ].joined(separator: lineEnding)
    }

    nonisolated static func upsertingFrontmatterManifest(
        tabs: [EpdocNotebookTab],
        in markdown: String
    ) -> String? {
        guard let block = YAMLFrontmatterBlock.find(in: markdown) else { return nil }
        let renderedBody = renderedManifestBlock(tabs: tabs, lineEnding: block.lineEnding)
            .components(separatedBy: block.lineEnding)
            .map { "  \($0)" }
            .joined(separator: block.lineEnding)
        let replacement = "\(frontmatterKey): |\(block.lineEnding)\(renderedBody)\(block.lineEnding)"

        if let existing = block.blockScalarRange(forKey: frontmatterKey, in: markdown) {
            var output = markdown
            output.replaceSubrange(existing, with: replacement)
            return output
        }

        var output = markdown
        output.insert(contentsOf: replacement, at: block.closingDelimiterStart)
        return output
    }

    private nonisolated static func parseFencedManifest(in markdown: String) -> EpdocNotebookManifest? {
        var isInsideManifest = false
        var activeFence = ""
        var content: [ManifestLine] = []
        var manifestStartLine = 0
        var manifestStartOffset = 0
        var offset = 0
        var lineIndex = 0
        var lineStart = markdown.startIndex

        while lineStart < markdown.endIndex {
            guard offset <= manifestScanLimitUTF16 || isInsideManifest else {
                return nil
            }
            let lineEnd = markdown[lineStart...].firstIndex(of: "\n") ?? markdown.endIndex
            let line = String(markdown[lineStart..<lineEnd])
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if isInsideManifest {
                if trimmed.hasPrefix(activeFence) {
                    let tabs = parseManifestLines(content)
                    return EpdocNotebookManifest(
                        tabs: tabs,
                        source: .fenced(startLine: manifestStartLine, charOffset: manifestStartOffset)
                    )
                }
                content.append(ManifestLine(text: line, line: lineIndex + 1, charOffset: offset))
            } else if let fence = manifestFence(from: trimmed) {
                isInsideManifest = true
                activeFence = fence
                manifestStartLine = lineIndex + 1
                manifestStartOffset = offset
            }

            lineIndex += 1
            offset += line.utf16.count
            guard lineEnd < markdown.endIndex else { break }
            lineStart = markdown.index(after: lineEnd)
            offset += 1
        }

        return nil
    }

    private nonisolated static func parseFrontmatterManifest(in markdown: String) -> EpdocNotebookManifest? {
        guard let block = YAMLFrontmatterBlock.find(in: markdown),
              let value = block.blockScalarValue(forKey: frontmatterKey, in: markdown)
        else { return nil }
        let tabs = parseManifestLines(value.lines)
        return EpdocNotebookManifest(
            tabs: tabs,
            source: .frontmatter(startLine: value.startLine, charOffset: value.charOffset)
        )
    }

    private nonisolated static func manifestFence(from trimmedLine: String) -> String? {
        guard trimmedLine.hasPrefix("```") || trimmedLine.hasPrefix("~~~") else { return nil }
        let fence = String(trimmedLine.prefix(3))
        let info = trimmedLine
            .dropFirst(3)
            .trimmingCharacters(in: .whitespaces)
            .split(whereSeparator: { $0.isWhitespace })
            .first
            .map(String.init) ?? ""
        return info.lowercased() == fenceInfoString ? fence : nil
    }

    private nonisolated static func parseManifestLines(_ lines: [ManifestLine]) -> [EpdocNotebookTab] {
        var tabs: [EpdocNotebookTab] = []
        for line in lines {
            let trimmed = line.text.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("tab:") else { continue }
            let attributes = KeyValueLineParser.parse(String(trimmed.dropFirst(4)))
            guard let id = attributes["id"],
                  let rawType = attributes["type"],
                  let rawVersion = attributes["version"],
                  let version = Int(rawVersion)
            else { continue }
            let reference = attributes["ref"] ?? attributes["reference"] ?? ""
            let title = attributes["title"]?.trimmingCharacters(in: .whitespacesAndNewlines)
            tabs.append(
                EpdocNotebookTab(
                    id: id,
                    kind: EpdocNotebookTabKind(rawType),
                    version: version,
                    title: title?.isEmpty == false ? title! : EpdocNotebookTabKind(rawType).defaultTitle,
                    reference: reference,
                    line: line.line,
                    charOffset: line.charOffset,
                    rawLine: line.text
                )
            )
        }
        return tabs
    }
}

nonisolated struct EpdocNotebookTab: Identifiable, Equatable, Sendable {
    let id: String
    let kind: EpdocNotebookTabKind
    let version: Int
    let title: String
    let reference: String
    let line: Int
    let charOffset: Int
    let rawLine: String

    var isStableID: Bool {
        id == EpdocNotebookManifest.bodyTabID || UUID(uuidString: id) != nil
    }

    var isSupported: Bool {
        isStableID && version == 1 && kind.isKnown
    }

    var needsTombstone: Bool {
        !isSupported || reference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var manifestLine: String {
        "tab: id=\(KeyValueLineParser.renderValue(id)) type=\(KeyValueLineParser.renderValue(kind.rawValue)) version=\(version) title=\(KeyValueLineParser.renderValue(title)) ref=\(KeyValueLineParser.renderValue(reference))"
    }

    var canonicalReferenceLine: String {
        manifestLine
    }

    var containsInlineRowData: Bool {
        EpdocNotebookInlineRowDataGuard.contains(in: rawLine)
    }

}

nonisolated enum EpdocNotebookTabKind: Equatable, Sendable {
    case body
    case sheet
    case chat
    case unknown(String)

    init(_ rawValue: String) {
        switch rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "body":
            self = .body
        case "sheet", "dataset":
            self = .sheet
        case "chat":
            self = .chat
        default:
            self = .unknown(rawValue)
        }
    }

    var rawValue: String {
        switch self {
        case .body:
            "body"
        case .sheet:
            "sheet"
        case .chat:
            "chat"
        case .unknown(let value):
            value
        }
    }

    var defaultTitle: String {
        switch self {
        case .body:
            "Body"
        case .sheet:
            "Sheet"
        case .chat:
            "Chat"
        case .unknown(let value):
            value.isEmpty ? "Unknown tab" : "\(value) tab"
        }
    }

    var isKnown: Bool {
        switch self {
        case .body, .sheet, .chat:
            true
        case .unknown:
            false
        }
    }
}

nonisolated struct EpdocNotebookBlockReference: Equatable, Sendable {
    let id: String
    let kind: EpdocNotebookTabKind
    let version: Int
    let title: String
    let reference: String
    let line: Int
    let charOffset: Int
    let rawLine: String

    var isStableID: Bool {
        UUID(uuidString: id) != nil
    }

    var needsTombstone: Bool {
        !isStableID || version != 1 || !kind.isKnown
    }

    var canonicalReferenceLine: String {
        "{{epistemos-ref id=\(KeyValueLineParser.renderValue(id)) type=\(KeyValueLineParser.renderValue(kind.rawValue)) version=\(version) title=\(KeyValueLineParser.renderValue(title)) ref=\(KeyValueLineParser.renderValue(reference))}}"
    }

    var containsInlineRowData: Bool {
        EpdocNotebookInlineRowDataGuard.contains(in: rawLine)
    }

}

nonisolated enum EpdocNotebookReferenceParser {
    nonisolated static func blockEmbeds(in markdown: String) -> [EpdocNotebookBlockReference] {
        var output: [EpdocNotebookBlockReference] = []
        var offset = 0
        for (lineIndex, line) in markdown.components(separatedBy: "\n").enumerated() {
            defer { offset += line.utf16.count + 1 }
            guard containsEmbed(line) else { continue }
            let attributes = KeyValueLineParser.parse(line)
            guard let id = attributes["id"],
                  let rawType = attributes["type"],
                  let rawVersion = attributes["version"],
                  let version = Int(rawVersion)
            else { continue }
            let kind = EpdocNotebookTabKind(rawType)
            let title = attributes["title"]?.trimmingCharacters(in: .whitespacesAndNewlines)
            output.append(
                EpdocNotebookBlockReference(
                    id: id,
                    kind: kind,
                    version: version,
                    title: title?.isEmpty == false ? title! : kind.defaultTitle,
                    reference: attributes["ref"] ?? attributes["reference"] ?? "",
                    line: lineIndex + 1,
                    charOffset: offset,
                    rawLine: line
                )
            )
        }
        return output
    }

    nonisolated static func containsEmbed(_ line: String) -> Bool {
        line.range(of: "epistemos-ref", options: [.caseInsensitive]) != nil
    }
}

nonisolated private enum EpdocNotebookInlineRowDataGuard {
    private static let inlineRowDataKeys: Set<String> = [
        "rows",
        "rowdata",
        "records",
        "values",
        "cells",
        "csv",
        "tsv",
    ]

    static func contains(in source: String) -> Bool {
        KeyValueLineParser.parse(source).keys.contains { key in
            inlineRowDataKeys.contains(
                key
                    .replacingOccurrences(of: "-", with: "")
                    .replacingOccurrences(of: "_", with: "")
                    .lowercased()
            )
        }
    }
}

nonisolated private struct ManifestLine: Equatable, Sendable {
    let text: String
    let line: Int
    let charOffset: Int
}

nonisolated private enum KeyValueLineParser {
    nonisolated static func parse(_ source: String) -> [String: String] {
        var values: [String: String] = [:]
        let characters = Array(source)
        var index = characters.startIndex

        while index < characters.endIndex {
            while index < characters.endIndex, characters[index].isWhitespace || characters[index] == "{" || characters[index] == "}" {
                index += 1
            }

            let keyStart = index
            while index < characters.endIndex,
                  characters[index].isLetter || characters[index].isNumber || characters[index] == "_" || characters[index] == "-" {
                index += 1
            }
            guard keyStart < index else {
                index = characters.index(after: index)
                continue
            }
            let key = String(characters[keyStart..<index]).lowercased()

            while index < characters.endIndex, characters[index].isWhitespace { index += 1 }
            guard index < characters.endIndex, characters[index] == "=" || characters[index] == ":" else { continue }
            index += 1
            while index < characters.endIndex, characters[index].isWhitespace { index += 1 }

            let value: String
            if index < characters.endIndex, characters[index] == "\"" {
                index += 1
                var output = ""
                var escaped = false
                while index < characters.endIndex {
                    let character = characters[index]
                    index += 1
                    if escaped {
                        switch character {
                        case "n": output.append("\n")
                        case "r": output.append("\r")
                        case "t": output.append("\t")
                        case "\"": output.append("\"")
                        case "\\": output.append("\\")
                        default: output.append(character)
                        }
                        escaped = false
                    } else if character == "\\" {
                        escaped = true
                    } else if character == "\"" {
                        break
                    } else {
                        output.append(character)
                    }
                }
                value = output
            } else {
                let valueStart = index
                while index < characters.endIndex,
                      !characters[index].isWhitespace,
                      characters[index] != "}",
                      characters[index] != "," {
                    index += 1
                }
                value = String(characters[valueStart..<index])
            }

            values[key] = value
        }

        return values
    }

    nonisolated static func renderValue(_ value: String) -> String {
        let plainPattern = #"^[A-Za-z0-9._:/@+-]+$"#
        if value.range(of: plainPattern, options: .regularExpression) != nil {
            return value
        }
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
        return "\"\(escaped)\""
    }
}

nonisolated private struct YAMLFrontmatterBlock: Equatable, Sendable {
    let contentRange: Range<String.Index>
    let closingDelimiterStart: String.Index
    let lineEnding: String
    let openingLineStart: String.Index

    struct ScalarValue: Equatable, Sendable {
        let lines: [ManifestLine]
        let startLine: Int
        let charOffset: Int
    }

    static func find(in markdown: String) -> YAMLFrontmatterBlock? {
        var cursor = markdown.startIndex
        if cursor < markdown.endIndex, markdown[cursor...].hasPrefix("\u{feff}") {
            cursor = markdown.index(after: cursor)
        }
        guard let opening = lineBounds(in: markdown, start: cursor),
              markerLine(in: markdown, bounds: opening) == "---"
        else { return nil }

        var lineStart = opening.nextLineStart
        while lineStart < markdown.endIndex {
            guard let bounds = lineBounds(in: markdown, start: lineStart) else { return nil }
            if markerLine(in: markdown, bounds: bounds) == "---" {
                return YAMLFrontmatterBlock(
                    contentRange: opening.nextLineStart..<lineStart,
                    closingDelimiterStart: lineStart,
                    lineEnding: opening.lineEnding.isEmpty ? "\n" : opening.lineEnding,
                    openingLineStart: cursor
                )
            }
            lineStart = bounds.nextLineStart
        }
        return nil
    }

    func blockScalarValue(forKey key: String, in markdown: String) -> ScalarValue? {
        guard let range = blockScalarRange(forKey: key, in: markdown) else { return nil }
        let prefix = markdown[..<range.lowerBound]
        let startLine = prefix.reduce(1) { count, character in count + (character == "\n" ? 1 : 0) }
        let charOffset = prefix.utf16.count
        var lines: [ManifestLine] = []

        guard let keyLine = Self.lineBounds(in: markdown, start: range.lowerBound) else {
            return ScalarValue(lines: [], startLine: startLine, charOffset: charOffset)
        }

        var lineStart = keyLine.nextLineStart
        var lineNumber = startLine + 1
        while lineStart < range.upperBound {
            guard let bounds = Self.lineBounds(in: markdown, start: lineStart) else { break }
            let contentEnd = min(bounds.contentEnd, range.upperBound)
            let line = String(markdown[bounds.contentStart..<contentEnd])
            if line.hasPrefix("  ") {
                let manifestTextStart = markdown.index(bounds.contentStart, offsetBy: 2)
                lines.append(
                    ManifestLine(
                        text: String(markdown[manifestTextStart..<contentEnd]),
                        line: lineNumber,
                        charOffset: markdown[..<manifestTextStart].utf16.count
                    )
                )
            }
            guard bounds.nextLineStart > lineStart else { break }
            lineStart = bounds.nextLineStart
            lineNumber += 1
        }

        return ScalarValue(lines: lines, startLine: startLine, charOffset: charOffset)
    }

    func blockScalarRange(forKey key: String, in markdown: String) -> Range<String.Index>? {
        var lineStart = contentRange.lowerBound
        while lineStart < contentRange.upperBound {
            guard let bounds = Self.lineBounds(in: markdown, start: lineStart),
                  bounds.contentStart < contentRange.upperBound
            else { return nil }
            let line = String(markdown[bounds.contentStart..<bounds.contentEnd])
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "\(key): |" || trimmed == "\(key): |-" || trimmed == "\(key): |+" {
                var scalarEnd = bounds.nextLineStart
                var scan = bounds.nextLineStart
                while scan < contentRange.upperBound {
                    guard let nextBounds = Self.lineBounds(in: markdown, start: scan) else { break }
                    let nextLine = String(markdown[nextBounds.contentStart..<nextBounds.contentEnd])
                    if !nextLine.isEmpty,
                       !nextLine.hasPrefix(" "),
                       !nextLine.hasPrefix("\t") {
                        break
                    }
                    scalarEnd = nextBounds.nextLineStart
                    scan = nextBounds.nextLineStart
                }
                return bounds.contentStart..<scalarEnd
            }
            lineStart = bounds.nextLineStart
        }
        return nil
    }

    private struct LineBounds {
        let contentStart: String.Index
        let contentEnd: String.Index
        let nextLineStart: String.Index
        let lineEnding: String
    }

    private static func lineBounds(in text: String, start: String.Index) -> LineBounds? {
        guard start <= text.endIndex else { return nil }
        let scalars = text.unicodeScalars
        guard let scalarStart = start.samePosition(in: scalars) else { return nil }
        let newline = "\n".unicodeScalars.first!
        let carriageReturn = "\r".unicodeScalars.first!

        var index = scalarStart
        while index < scalars.endIndex {
            let scalar = scalars[index]
            if scalar == newline {
                guard let contentEnd = String.Index(index, within: text),
                      let nextLineStart = String.Index(scalars.index(after: index), within: text)
                else { return nil }
                return LineBounds(
                    contentStart: start,
                    contentEnd: contentEnd,
                    nextLineStart: nextLineStart,
                    lineEnding: "\n"
                )
            }
            if scalar == carriageReturn {
                let afterReturn = scalars.index(after: index)
                guard let contentEnd = String.Index(index, within: text) else { return nil }
                if afterReturn < scalars.endIndex, scalars[afterReturn] == newline {
                    guard let nextLineStart = String.Index(scalars.index(after: afterReturn), within: text) else {
                        return nil
                    }
                    return LineBounds(
                        contentStart: start,
                        contentEnd: contentEnd,
                        nextLineStart: nextLineStart,
                        lineEnding: "\r\n"
                    )
                }
                guard let nextLineStart = String.Index(afterReturn, within: text) else { return nil }
                return LineBounds(
                    contentStart: start,
                    contentEnd: contentEnd,
                    nextLineStart: nextLineStart,
                    lineEnding: "\r"
                )
            }
            index = scalars.index(after: index)
        }

        return LineBounds(
            contentStart: start,
            contentEnd: text.endIndex,
            nextLineStart: text.endIndex,
            lineEnding: ""
        )
    }

    private static func markerLine(in text: String, bounds: LineBounds) -> String {
        String(text[bounds.contentStart..<bounds.contentEnd])
            .trimmingCharacters(in: .whitespaces)
    }
}
