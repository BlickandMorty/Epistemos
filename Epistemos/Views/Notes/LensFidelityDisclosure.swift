import AppKit
import SwiftUI

enum LensFidelityState: String, Equatable {
    case rendered
    case degraded
    case invisible

    var label: String {
        switch self {
        case .rendered:
            "Rendered"
        case .degraded:
            "Degraded"
        case .invisible:
            "Invisible"
        }
    }

    var symbolName: String {
        switch self {
        case .rendered:
            "checkmark.circle"
        case .degraded:
            "exclamationmark.triangle"
        case .invisible:
            "eye.slash"
        }
    }
}

struct LensFidelityDisclosureItem: Identifiable, Equatable {
    let id: String
    let type: String
    let label: String
    let state: LensFidelityState
    let line: Int
    let preview: LensFidelityPreview
    let exports: [LensFidelityExport]

    var exportText: String {
        primaryExport?.textRepresentation ?? ""
    }

    var exportSuggestedFilename: String {
        primaryExport?.filename ?? "lens-fidelity-\(type)-line-\(line).txt"
    }

    var exportActionLabel: String {
        primaryExport?.kind.actionLabel ?? "Export Raw"
    }

    var primaryExport: LensFidelityExport? {
        exports.first
    }
}

enum LensFidelityExportKind: String, Equatable {
    case markdown
    case raw
    case image
    case csv
    case xlsx
    case transcript

    var actionLabel: String {
        switch self {
        case .markdown:
            "Export Markdown"
        case .raw:
            "Export Raw"
        case .image:
            "Export Image"
        case .csv:
            "Export CSV"
        case .xlsx:
            "Export XLSX"
        case .transcript:
            "Export Transcript"
        }
    }
}

struct LensFidelityExport: Identifiable, Equatable {
    let kind: LensFidelityExportKind
    let filename: String
    let data: Data
    let textRepresentation: String?

    var id: String {
        "\(kind.rawValue)-\(filename)"
    }

    init(kind: LensFidelityExportKind, filename: String, text: String) {
        self.kind = kind
        self.filename = filename
        self.data = Data(text.utf8)
        self.textRepresentation = text
    }

    init(kind: LensFidelityExportKind, filename: String, data: Data, textRepresentation: String? = nil) {
        self.kind = kind
        self.filename = filename
        self.data = data
        self.textRepresentation = textRepresentation
    }
}

struct LensFidelityDatasetReference: Equatable {
    let disclosureType: String
    let title: String
    let reference: String
    let source: String
    let line: Int
}

protocol LensFidelityDatasetExportProviding {
    func exports(for dataset: LensFidelityDatasetReference) -> [LensFidelityExport]
}

struct LensFidelityChartPoint: Equatable {
    let label: String
    let x: Double
    let y: Double
}

struct LensFidelityChartPreview: Equatable {
    let kind: String
    let title: String
    let points: [LensFidelityChartPoint]
    let provenance: String
    let source: String
}

enum LensFidelityPreview: Equatable {
    case chart(LensFidelityChartPreview)
    case table(headers: [String], rows: [[String]])
    case transcript(title: String, reference: String)
    case reference(kind: String, title: String, reference: String)
    case markdown(String)
    case raw(String)

    var plainText: String {
        switch self {
        case .chart(let chart):
            return "\(chart.title) · \(chart.kind) · \(chart.points.count) points"
        case .table(let headers, let rows):
            let header = headers.joined(separator: ", ")
            return "\(header)\n\(rows.prefix(3).map { $0.joined(separator: ", ") }.joined(separator: "\n"))"
        case .transcript(let title, let reference):
            return "\(title)\n\(reference)"
        case .reference(let kind, let title, let reference):
            return "\(kind): \(title)\n\(reference)"
        case .markdown(let text), .raw(let text):
            return text
        }
    }
}

enum LensFidelityDisclosure {
    static func items(
        in markdown: String,
        lens: NoteWorkspaceMode,
        chatTabContentAvailable: Bool = EpdocNotebookBuildCapabilities.isChatTabContentAvailable,
        datasetExportProvider: (any LensFidelityDatasetExportProviding)? = nil
    ) -> [LensFidelityDisclosureItem] {
        guard !markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

        var items: [LensFidelityDisclosureItem] = []
        let lines = markdown.components(separatedBy: .newlines)
        scanFencedBlocks(lines, lens: lens, into: &items)
        scanNotebookReferences(
            markdown,
            lens: lens,
            chatTabContentAvailable: chatTabContentAvailable,
            datasetExportProvider: datasetExportProvider,
            into: &items
        )
        scanInlineMarkdown(lines, lens: lens, datasetExportProvider: datasetExportProvider, into: &items)
        return items
    }

    private static func scanFencedBlocks(
        _ lines: [String],
        lens: NoteWorkspaceMode,
        into items: inout [LensFidelityDisclosureItem]
    ) {
        var index = 0
        while index < lines.count {
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") else {
                index += 1
                continue
            }

            let fence = String(trimmed.prefix(3))
            let info = trimmed.dropFirst(3)
                .trimmingCharacters(in: .whitespaces)
                .split(whereSeparator: { $0.isWhitespace })
                .first
                .map { String($0).lowercased() } ?? ""
            var end = index + 1
            while end < lines.count,
                  !lines[end].trimmingCharacters(in: .whitespaces).hasPrefix(fence) {
                end += 1
            }
            let blockEnd = min(end, lines.count - 1)
            let raw = lines[index...blockEnd].joined(separator: "\n")
            let lineNumber = index + 1

            if info == "chart" || (info == "json" && containsChartSpec(raw)) {
                append(
                    type: "epdocChart",
                    label: "Chart",
                    raw: raw,
                    line: lineNumber,
                    lens: lens,
                    into: &items
                )
            } else if info == "mermaid" {
                append(
                    type: "mermaid",
                    label: "Legacy diagram",
                    raw: raw,
                    line: lineNumber,
                    lens: lens,
                    into: &items
                )
            }

            index = max(index + 1, end + 1)
        }
    }

    private static func scanInlineMarkdown(
        _ lines: [String],
        lens: NoteWorkspaceMode,
        datasetExportProvider: (any LensFidelityDatasetExportProviding)?,
        into items: inout [LensFidelityDisclosureItem]
    ) {
        var index = 0
        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let lineNumber = index + 1

            if line.contains("epistemos-quarantine:start") {
                var end = index
                while end < lines.count,
                      !lines[end].contains("epistemos-quarantine:end") {
                    end += 1
                }
                let blockEnd = min(end, lines.count - 1)
                let raw = lines[index...blockEnd].joined(separator: "\n")
                append(
                    type: "opaqueQuarantine",
                    label: "Quarantined block",
                    raw: raw,
                    line: lineNumber,
                    lens: lens,
                    into: &items
                )
                index = blockEnd + 1
                continue
            }
            if trimmed == "$$" {
                var end = index + 1
                while end < lines.count,
                      lines[end].trimmingCharacters(in: .whitespaces) != "$$" {
                    end += 1
                }
                let blockEnd = min(end, lines.count - 1)
                append(
                    type: "blockMath",
                    label: "Block math",
                    raw: lines[index...blockEnd].joined(separator: "\n"),
                    line: lineNumber,
                    lens: lens,
                    into: &items
                )
                index = blockEnd + 1
                continue
            } else if containsInlineMath(line) {
                append(
                    type: "inlineMath",
                    label: "Inline math",
                    raw: line,
                    line: lineNumber,
                    lens: lens,
                    into: &items
                )
            }
            if trimmed.uppercased().hasPrefix("> [!") {
                append(
                    type: "callout",
                    label: "Callout",
                    raw: line,
                    line: lineNumber,
                    lens: lens,
                    into: &items
                )
            }
            if looksLikeTableDivider(trimmed),
               index > lines.startIndex,
               lines[index - 1].contains("|") {
                var tableEnd = index
                while tableEnd + 1 < lines.count,
                      lines[tableEnd + 1].contains("|"),
                      !looksLikeTableDivider(lines[tableEnd + 1].trimmingCharacters(in: .whitespaces)) {
                    tableEnd += 1
                }
                append(
                    type: "table",
                    label: "Table",
                    raw: lines[(index - 1)...tableEnd].joined(separator: "\n"),
                    line: lineNumber - 1,
                    lens: lens,
                    into: &items
                )
                index = tableEnd + 1
                continue
            }
            if matches(line, #"^\s*[-*+]\s+\[[ xX]\]\s+"#) {
                append(
                    type: "taskList",
                    label: "Task list",
                    raw: line,
                    line: lineNumber,
                    lens: lens,
                    into: &items
                )
            }
            if line.contains("![") && line.contains("](") {
                append(
                    type: "epdocImage",
                    label: "Package image",
                    raw: line,
                    line: lineNumber,
                    lens: lens,
                    into: &items
                )
            }
            if line.contains("[[") && line.contains("]]") {
                append(
                    type: "wikilink",
                    label: "Wikilink",
                    raw: line,
                    line: lineNumber,
                    lens: lens,
                    into: &items
                )
            }
            if line.contains("==") {
                append(
                    type: "highlight",
                    label: "Highlight",
                    raw: line,
                    line: lineNumber,
                    lens: lens,
                    into: &items
                )
            }
            if !EpdocNotebookReferenceParser.containsEmbed(line),
               containsDatasetEmbed(line) {
                append(
                    type: "datasetEmbed",
                    label: "Dataset embed",
                    raw: line,
                    line: lineNumber,
                    lens: lens,
                    datasetExportProvider: datasetExportProvider,
                    into: &items
                )
            }
            index += 1
        }
    }

    private static func scanNotebookReferences(
        _ markdown: String,
        lens: NoteWorkspaceMode,
        chatTabContentAvailable: Bool,
        datasetExportProvider: (any LensFidelityDatasetExportProviding)?,
        into items: inout [LensFidelityDisclosureItem]
    ) {
        let manifest = EpdocNotebookManifest.parse(in: markdown)
        for tab in manifest.tabs {
            append(
                type: disclosureType(for: tab),
                label: disclosureLabel(for: tab),
                raw: tab.rawLine,
                line: tab.line,
                lens: lens,
                chatTabContentAvailable: chatTabContentAvailable,
                preview: preview(for: tab),
                providedExports: exports(for: tab, datasetExportProvider: datasetExportProvider),
                into: &items
            )
        }

        for embed in EpdocNotebookReferenceParser.blockEmbeds(in: markdown) {
            append(
                type: disclosureType(for: embed),
                label: embed.kind == .sheet ? "Dataset embed" : "\(embed.kind.defaultTitle) embed",
                raw: embed.rawLine,
                line: embed.line,
                lens: lens,
                chatTabContentAvailable: chatTabContentAvailable,
                preview: preview(for: embed),
                providedExports: exports(for: embed, datasetExportProvider: datasetExportProvider),
                into: &items
            )
        }
    }

    private static func append(
        type: String,
        label: String,
        raw: String,
        line: Int,
        lens: NoteWorkspaceMode,
        chatTabContentAvailable: Bool = EpdocNotebookBuildCapabilities.isChatTabContentAvailable,
        preview: LensFidelityPreview? = nil,
        providedExports: [LensFidelityExport]? = nil,
        datasetExportProvider: (any LensFidelityDatasetExportProviding)? = nil,
        into items: inout [LensFidelityDisclosureItem]
    ) {
        let state = fidelityState(for: type, lens: lens, chatTabContentAvailable: chatTabContentAvailable)
        guard state != .rendered else { return }
        items.append(
            LensFidelityDisclosureItem(
                id: "\(type)-\(line)-\(stableHash(raw))",
                type: type,
                label: label,
                state: state,
                line: line,
                preview: preview ?? renderedPreview(type: type, label: label, raw: raw),
                exports: providedExports ?? exports(
                    for: type,
                    label: label,
                    raw: raw,
                    line: line,
                    datasetExportProvider: datasetExportProvider
                )
            )
        )
    }

    private static func fidelityState(
        for type: String,
        lens: NoteWorkspaceMode,
        chatTabContentAvailable: Bool
    ) -> LensFidelityState {
        switch lens {
        case .edit:
            if [
                "blockMath",
                "epdocChart",
                "mermaid",
                "datasetEmbed",
                "opaqueQuarantine",
                "notebookSheetTab",
                "notebookChatTab",
                "notebookUnknownTab",
                "notebookEmbed",
            ].contains(type) {
                return .invisible
            }
            return .degraded
        case .source:
            return .degraded
        case .preview:
            if [
                "blockMath",
                "epdocChart",
                "mermaid",
                "datasetEmbed",
                "opaqueQuarantine",
                "notebookSheetTab",
                "notebookChatTab",
                "notebookUnknownTab",
                "notebookEmbed",
            ].contains(type) {
                return .degraded
            }
            return .rendered
        case .document:
            if type == "notebookChatTab" {
                return chatTabContentAvailable ? .rendered : .degraded
            }
            if ["opaqueQuarantine", "datasetEmbed", "notebookUnknownTab", "notebookEmbed"].contains(type) {
                return .degraded
            }
            return .rendered
        }
    }

    private static func containsChartSpec(_ source: String) -> Bool {
        matches(source, #""type"\s*:\s*"(scatter|bar|line)""#)
    }

    private static func containsInlineMath(_ source: String) -> Bool {
        guard !source.contains("$$") else { return false }
        return matches(source, #"(^|[^\\])\$[^$\n]+\$"#)
    }

    private static func containsDatasetEmbed(_ source: String) -> Bool {
        let lowercased = source.lowercased()
        return lowercased.contains("dataset:")
            || lowercased.contains("datasetid")
            || lowercased.contains(".dataset.md")
    }

    private static func looksLikeTableDivider(_ source: String) -> Bool {
        matches(source, #"^\|?\s*:?-{3,}:?\s*(\|\s*:?-{3,}:?\s*)+\|?\s*$"#)
    }

    private static func matches(_ source: String, _ pattern: String) -> Bool {
        source.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private static func renderedPreview(type: String, label: String, raw: String) -> LensFidelityPreview {
        switch type {
        case "epdocChart":
            if let chart = chartPreview(from: raw) {
                return .chart(chart)
            }
            return .raw(boundedPreview(raw))
        case "table":
            if let table = markdownTable(from: raw) {
                return .table(headers: table.headers, rows: table.rows)
            }
            return .markdown(boundedPreview(raw))
        case "datasetEmbed", "notebookSheetTab":
            let source = sanitizedDatasetReferenceSource(from: raw)
            return .reference(kind: "Dataset", title: label, reference: referenceSummary(from: source))
        case "notebookChatTab":
            return .transcript(title: label, reference: referenceSummary(from: raw))
        case "opaqueQuarantine", "notebookUnknownTab", "notebookEmbed":
            return .raw(boundedPreview(raw))
        default:
            return .markdown(boundedPreview(raw))
        }
    }

    private static func boundedPreview(_ raw: String) -> String {
        let normalized = raw
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.count <= 140 {
            return normalized
        }
        return "\(normalized.prefix(137))..."
    }

    private static func exports(
        for type: String,
        label: String,
        raw: String,
        line: Int,
        datasetExportProvider: (any LensFidelityDatasetExportProviding)? = nil
    ) -> [LensFidelityExport] {
        switch type {
        case "epdocChart":
            if let chart = chartPreview(from: raw) {
                return [
                    LensFidelityExport(
                        kind: .image,
                        filename: suggestedFilename(type: type, line: line, suffix: "svg"),
                        text: svgImage(for: chart)
                    ),
                    LensFidelityExport(
                        kind: .raw,
                        filename: suggestedFilename(type: type, line: line, suffix: "json"),
                        text: chart.source
                    ),
                ]
            }
            return [rawExport(type: type, raw: raw, line: line)]
        case "mermaid":
            return [
                LensFidelityExport(
                    kind: .image,
                    filename: suggestedFilename(type: type, line: line, suffix: "svg"),
                    text: svgTextImage(title: label, body: fencedBody(from: raw) ?? raw)
                ),
                rawExport(type: type, raw: raw, line: line),
            ]
        case "blockMath":
            return [
                LensFidelityExport(
                    kind: .image,
                    filename: suggestedFilename(type: type, line: line, suffix: "svg"),
                    text: svgTextImage(title: label, body: raw.replacingOccurrences(of: "$$", with: ""))
                ),
                markdownExport(type: type, raw: raw, line: line),
            ]
        case "table":
            if let table = markdownTable(from: raw) {
                return [
                    LensFidelityExport(
                        kind: .csv,
                        filename: suggestedFilename(type: type, line: line, suffix: "csv"),
                        text: csv(headers: table.headers, rows: table.rows)
                    ),
                    markdownExport(type: type, raw: raw, line: line),
                ]
            }
            return [markdownExport(type: type, raw: raw, line: line)]
        case "datasetEmbed", "notebookSheetTab":
            let source = sanitizedDatasetReferenceSource(from: raw)
            return datasetExports(
                type: type,
                title: label,
                reference: referenceSummary(from: source),
                source: source,
                line: line,
                datasetExportProvider: datasetExportProvider,
                fallback: [markdownExport(type: type, raw: source, line: line)]
            )
        case "notebookChatTab":
            return [
                LensFidelityExport(
                    kind: .transcript,
                    filename: suggestedFilename(type: type, line: line, suffix: "md"),
                    text: transcriptMarkdown(title: label, reference: referenceSummary(from: raw), source: raw)
                ),
            ]
        case "opaqueQuarantine", "notebookUnknownTab", "notebookEmbed":
            return [rawExport(type: type, raw: raw, line: line)]
        case "callout", "taskList", "wikilink", "highlight", "inlineMath":
            return [markdownExport(type: type, raw: raw, line: line)]
        default:
            return [rawExport(type: type, raw: raw, line: line)]
        }
    }

    private static func exports(
        for tab: EpdocNotebookTab,
        datasetExportProvider: (any LensFidelityDatasetExportProviding)?
    ) -> [LensFidelityExport] {
        let type = disclosureType(for: tab)
        switch tab.kind {
        case .sheet:
            return datasetExports(
                type: type,
                title: tab.title,
                reference: tab.reference,
                source: tab.canonicalReferenceLine,
                line: tab.line,
                datasetExportProvider: datasetExportProvider
            )
        case .chat:
            return [
                LensFidelityExport(
                    kind: .transcript,
                    filename: suggestedFilename(type: type, line: tab.line, suffix: "md"),
                    text: transcriptMarkdown(title: tab.title, reference: tab.reference, source: tab.rawLine)
                ),
            ]
        case .unknown:
            return [rawExport(type: type, raw: tab.rawLine, line: tab.line)]
        case .body:
            return [markdownExport(type: type, raw: tab.rawLine, line: tab.line)]
        }
    }

    private static func exports(
        for embed: EpdocNotebookBlockReference,
        datasetExportProvider: (any LensFidelityDatasetExportProviding)?
    ) -> [LensFidelityExport] {
        let type = disclosureType(for: embed)
        switch embed.kind {
        case .sheet:
            return datasetExports(
                type: type,
                title: embed.title,
                reference: embed.reference,
                source: embed.canonicalReferenceLine,
                line: embed.line,
                datasetExportProvider: datasetExportProvider
            )
        case .chat:
            return [
                LensFidelityExport(
                    kind: .transcript,
                    filename: suggestedFilename(type: type, line: embed.line, suffix: "md"),
                    text: transcriptMarkdown(title: embed.title, reference: embed.reference, source: embed.rawLine)
                ),
            ]
        case .body, .unknown:
            return [rawExport(type: type, raw: embed.rawLine, line: embed.line)]
        }
    }

    private static func datasetExports(
        type: String,
        title: String,
        reference: String,
        source: String,
        line: Int,
        datasetExportProvider: (any LensFidelityDatasetExportProviding)?,
        fallback: [LensFidelityExport] = []
    ) -> [LensFidelityExport] {
        let dataset = LensFidelityDatasetReference(
            disclosureType: type,
            title: title,
            reference: reference,
            source: source,
            line: line
        )
        let provided = prioritizedDatasetExports(datasetExportProvider?.exports(for: dataset) ?? [])
        guard provided.isEmpty else { return provided }
        return [
            LensFidelityExport(
                kind: .csv,
                filename: suggestedFilename(type: type, line: line, suffix: "csv"),
                text: referenceCSV(kind: "dataset", title: title, reference: reference, source: source)
            ),
        ] + fallback
    }

    private static func prioritizedDatasetExports(_ exports: [LensFidelityExport]) -> [LensFidelityExport] {
        let priority: [LensFidelityExportKind: Int] = [
            .xlsx: 0,
            .csv: 1,
            .markdown: 2,
            .raw: 3,
            .image: 4,
            .transcript: 5,
        ]
        return exports.sorted {
            (priority[$0.kind] ?? Int.max, $0.filename) < (priority[$1.kind] ?? Int.max, $1.filename)
        }
    }

    private static func preview(for tab: EpdocNotebookTab) -> LensFidelityPreview {
        switch tab.kind {
        case .chat:
            return .transcript(title: tab.title, reference: tab.reference)
        case .sheet:
            return .reference(kind: "Dataset", title: tab.title, reference: tab.reference)
        case .body:
            return .markdown(tab.rawLine)
        case .unknown(let kind):
            return .reference(kind: kind, title: tab.title, reference: tab.reference)
        }
    }

    private static func preview(for embed: EpdocNotebookBlockReference) -> LensFidelityPreview {
        switch embed.kind {
        case .chat:
            return .transcript(title: embed.title, reference: embed.reference)
        case .sheet:
            return .reference(kind: "Dataset", title: embed.title, reference: embed.reference)
        case .body:
            return .reference(kind: "Notebook", title: embed.title, reference: embed.reference)
        case .unknown(let kind):
            return .reference(kind: kind, title: embed.title, reference: embed.reference)
        }
    }

    private static func suggestedFilename(type: String, line: Int, suffix: String) -> String {
        "lens-fidelity-\(type)-line-\(line).\(suffix)"
    }

    private static func rawExport(type: String, raw: String, line: Int) -> LensFidelityExport {
        LensFidelityExport(
            kind: .raw,
            filename: suggestedFilename(type: type, line: line, suffix: "txt"),
            text: raw
        )
    }

    private static func markdownExport(type: String, raw: String, line: Int) -> LensFidelityExport {
        LensFidelityExport(
            kind: .markdown,
            filename: suggestedFilename(type: type, line: line, suffix: "md"),
            text: raw
        )
    }

    private static func transcriptMarkdown(title: String, reference: String, source: String) -> String {
        """
        # \(title)

        Transcript reference: `\(reference.isEmpty ? "unresolved" : reference)`

        ```epistemos-notebook-reference
        \(source)
        ```
        """
    }

    private static func referenceCSV(kind: String, title: String, reference: String, source: String) -> String {
        csv(
            headers: ["kind", "title", "reference", "source"],
            rows: [[kind, title, reference, source]]
        )
    }

    private static func sanitizedDatasetReferenceSource(from raw: String) -> String {
        let rowAttribute = #"(?i)\s+(rows|row[-_]?data|records|values|cells|csv|tsv)\s*=\s*"[^"]*""#
        let unquotedRowAttribute = #"(?i)\s+(rows|row[-_]?data|records|values|cells|csv|tsv)\s*=\s*[^\s"}]+"#
        return raw
            .replacingOccurrences(of: rowAttribute, with: "", options: .regularExpression)
            .replacingOccurrences(of: unquotedRowAttribute, with: "", options: .regularExpression)
            .replacingOccurrences(of: #" {2,}"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func referenceSummary(from raw: String) -> String {
        if let ref = KeyValueReferenceParser.value(for: "ref", in: raw)
            ?? KeyValueReferenceParser.value(for: "reference", in: raw) {
            return ref
        }
        if let datasetRange = raw.range(of: #"dataset:[^\s"}]+"#, options: .regularExpression) {
            return String(raw[datasetRange])
        }
        return boundedPreview(raw)
    }

    private static func fencedBody(from raw: String) -> String? {
        var lines = raw.components(separatedBy: .newlines)
        let firstLine = lines.first?.trimmingCharacters(in: .whitespaces) ?? ""
        guard lines.count >= 3,
              firstLine.hasPrefix("```") || firstLine.hasPrefix("~~~")
        else { return nil }
        lines.removeFirst()
        if lines.last?.trimmingCharacters(in: .whitespaces).hasPrefix("```") == true
            || lines.last?.trimmingCharacters(in: .whitespaces).hasPrefix("~~~") == true {
            lines.removeLast()
        }
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func chartPreview(from raw: String) -> LensFidelityChartPreview? {
        let source = fencedBody(from: raw) ?? raw
        guard let data = source.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let kind = json["type"] as? String,
              ["scatter", "bar", "line"].contains(kind),
              let provenance = chartProvenanceSummary(from: json)
        else { return nil }

        let title = (json["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        var points: [LensFidelityChartPoint] = []
        if let rawBars = json["bars"] as? [[String: Any]] {
            points = rawBars.enumerated().compactMap { index, bar in
                guard let value = number(bar["value"]) else { return nil }
                let label = (bar["label"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                return LensFidelityChartPoint(label: label?.isEmpty == false ? label! : "Bar \(index + 1)", x: Double(index), y: value)
            }
        } else if let rawPoints = json["points"] as? [[String: Any]] {
            points = rawPoints.enumerated().compactMap { index, point in
                guard let x = number(point["x"]),
                      let y = number(point["y"])
                else { return nil }
                let label = (point["label"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                    ?? (point["category"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                return LensFidelityChartPoint(label: label?.isEmpty == false ? label! : "Point \(index + 1)", x: x, y: y)
            }
        }
        guard !points.isEmpty else { return nil }
        return LensFidelityChartPreview(
            kind: kind,
            title: title?.isEmpty == false ? title! : "\(kind.capitalized) chart",
            points: points,
            provenance: provenance,
            source: source
        )
    }

    private static func chartProvenanceSummary(from json: [String: Any]) -> String? {
        guard let provenance = json["provenance"] as? [String: Any] else {
            return nil
        }
        let ledgerPointer = (provenance["ledgerPointer"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        if ledgerPointer?.isEmpty == false {
            return ledgerPointer
        }
        let datasetID = (provenance["datasetId"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let range = (provenance["range"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let datasetID, !datasetID.isEmpty, let range, !range.isEmpty {
            return "\(datasetID) \(range)"
        }
        if let datasetID, !datasetID.isEmpty {
            return datasetID
        }
        let source = (provenance["source"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let source, !source.isEmpty {
            return source
        }
        return nil
    }

    private static func number(_ value: Any?) -> Double? {
        if let value = value as? Double, value.isFinite { return value }
        if let value = value as? Int { return Double(value) }
        if let value = value as? NSNumber {
            let double = value.doubleValue
            return double.isFinite ? double : nil
        }
        return nil
    }

    private static func markdownTable(from raw: String) -> (headers: [String], rows: [[String]])? {
        let tableLines = raw.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.contains("|") }
        guard tableLines.count >= 2 else { return nil }
        let headers = markdownTableCells(in: tableLines[0])
        guard !headers.isEmpty,
              looksLikeTableDivider(tableLines[1])
        else { return nil }
        let rows = tableLines.dropFirst(2).map(markdownTableCells(in:))
        return (headers, rows)
    }

    private static func markdownTableCells(in line: String) -> [String] {
        var trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("|") { trimmed.removeFirst() }
        if trimmed.hasSuffix("|") { trimmed.removeLast() }
        return trimmed.split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private static func csv(headers: [String], rows: [[String]]) -> String {
        ([headers] + rows)
            .map { $0.map(csvCell).joined(separator: ",") }
            .joined(separator: "\n") + "\n"
    }

    private static func csvCell(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }

    private static func svgImage(for chart: LensFidelityChartPreview) -> String {
        let width = 720.0
        let height = 360.0
        let frameX = 64.0
        let frameY = 58.0
        let frameWidth = 600.0
        let frameHeight = 240.0
        let xValues = chart.points.map(\.x)
        let yValues = chart.points.map(\.y)
        let xDomain = domain(xValues)
        let yDomain = domain(yValues)
        let title = escapeXML(chart.title)
        var marks: [String] = []

        if chart.kind == "bar" {
            let barWidth = frameWidth / Double(max(chart.points.count, 1)) * 0.68
            for (index, point) in chart.points.enumerated() {
                let x = frameX + Double(index) * (frameWidth / Double(max(chart.points.count, 1))) + barWidth * 0.24
                let y = scale(point.y, from: yDomain, to: (frameY + frameHeight, frameY))
                let h = frameY + frameHeight - y
                marks.append("<rect x=\"\(format(x))\" y=\"\(format(y))\" width=\"\(format(barWidth))\" height=\"\(format(max(2, h)))\" rx=\"5\" fill=\"#4f7cff\"/>")
            }
        } else {
            let projected = chart.points
                .sorted { chart.kind == "line" ? $0.x < $1.x : $0.label < $1.label }
                .map { point in
                    (
                        x: scale(point.x, from: xDomain, to: (frameX, frameX + frameWidth)),
                        y: scale(point.y, from: yDomain, to: (frameY + frameHeight, frameY))
                    )
                }
            if chart.kind == "line", !projected.isEmpty {
                let path = projected.enumerated()
                    .map { index, point in "\(index == 0 ? "M" : "L") \(format(point.x)) \(format(point.y))" }
                    .joined(separator: " ")
                marks.append("<path d=\"\(path)\" fill=\"none\" stroke=\"#4f7cff\" stroke-width=\"4\" stroke-linecap=\"round\" stroke-linejoin=\"round\"/>")
            }
            marks += projected.map { point in
                "<circle cx=\"\(format(point.x))\" cy=\"\(format(point.y))\" r=\"6\" fill=\"#4f7cff\"/>"
            }
        }

        return """
        <svg xmlns="http://www.w3.org/2000/svg" width="\(Int(width))" height="\(Int(height))" viewBox="0 0 \(Int(width)) \(Int(height))" role="img" aria-label="\(title)">
          <rect width="100%" height="100%" rx="18" fill="#f8fafc"/>
          <text x="32" y="34" fill="#111827" font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="20" font-weight="700">\(title)</text>
          <text x="32" y="54" fill="#64748b" font-family="SFMono-Regular, Menlo, monospace" font-size="11">provenance: \(escapeXML(chart.provenance))</text>
          <line x1="\(format(frameX))" y1="\(format(frameY + frameHeight))" x2="\(format(frameX + frameWidth))" y2="\(format(frameY + frameHeight))" stroke="#94a3b8" stroke-width="2"/>
          <line x1="\(format(frameX))" y1="\(format(frameY))" x2="\(format(frameX))" y2="\(format(frameY + frameHeight))" stroke="#94a3b8" stroke-width="2"/>
          \(marks.joined(separator: "\n  "))
        </svg>
        """
    }

    private static func svgTextImage(title: String, body: String) -> String {
        let lines = body
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .prefix(7)
        let text = lines.enumerated().map { index, line in
            "<text x=\"32\" y=\"\(76 + index * 28)\" fill=\"#334155\" font-family=\"SFMono-Regular, Menlo, monospace\" font-size=\"16\">\(escapeXML(line))</text>"
        }.joined(separator: "\n  ")
        return """
        <svg xmlns="http://www.w3.org/2000/svg" width="720" height="300" viewBox="0 0 720 300" role="img" aria-label="\(escapeXML(title))">
          <rect width="100%" height="100%" rx="18" fill="#f8fafc"/>
          <text x="32" y="36" fill="#111827" font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="20" font-weight="700">\(escapeXML(title))</text>
          \(text)
        </svg>
        """
    }

    private static func domain(_ values: [Double]) -> ClosedRange<Double> {
        guard let minValue = values.min(),
              let maxValue = values.max()
        else { return 0...1 }
        if minValue == maxValue {
            return (minValue - 1)...(maxValue + 1)
        }
        return minValue...maxValue
    }

    private static func scale(_ value: Double, from domain: ClosedRange<Double>, to range: (Double, Double)) -> Double {
        let denominator = domain.upperBound - domain.lowerBound
        guard denominator != 0 else { return range.0 }
        let fraction = (value - domain.lowerBound) / denominator
        return range.0 + fraction * (range.1 - range.0)
    }

    private static func format(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private static func escapeXML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static func disclosureType(for tab: EpdocNotebookTab) -> String {
        switch tab.kind {
        case .body:
            "notebookBodyTab"
        case .sheet:
            "notebookSheetTab"
        case .chat:
            "notebookChatTab"
        case .unknown:
            "notebookUnknownTab"
        }
    }

    private static func disclosureLabel(for tab: EpdocNotebookTab) -> String {
        switch tab.kind {
        case .body, .sheet, .chat:
            "\(tab.kind.defaultTitle) tab"
        case .unknown:
            tab.kind.defaultTitle
        }
    }

    private static func disclosureType(for embed: EpdocNotebookBlockReference) -> String {
        switch embed.kind {
        case .sheet:
            "datasetEmbed"
        case .chat:
            "notebookChatTab"
        case .body:
            "notebookEmbed"
        case .unknown:
            "notebookEmbed"
        }
    }

    private static func stableHash(_ source: String) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in source.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(hash, radix: 16)
    }
}

enum LensFidelityDisclosureExporter {
    static func copy(_ item: LensFidelityDisclosureItem) {
        guard let export = item.primaryExport else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(
            export.textRepresentation ?? String(decoding: export.data, as: UTF8.self),
            forType: .string
        )
    }

    static func export(_ item: LensFidelityDisclosureItem) {
        guard let export = item.primaryExport else { return }
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = export.filename
        guard panel.runModal() == .OK,
              let url = panel.url
        else { return }

        do {
            try export.data.write(to: url, options: .atomic)
        } catch {
            NSSound.beep()
        }
    }
}

struct LensFidelityDisclosureSection: View {
    let items: [LensFidelityDisclosureItem]
    let onOpenDocument: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "checkerboard.shield")
                Text("Lens Fidelity")
                    .font(.headline)
                Spacer()
            }
            .foregroundStyle(.primary)

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(items) { item in
                        disclosureRow(item)
                    }
                }
            }
            .frame(maxHeight: 240)
        }
    }

    private func disclosureRow(_ item: LensFidelityDisclosureItem) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Image(systemName: item.state.symbolName)
                    .foregroundStyle(item.state == .invisible ? .red : .orange)
                Text(item.label)
                    .font(.callout.weight(.semibold))
                Spacer()
                Text("Line \(item.line)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(item.state.label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            previewView(item.preview)

            HStack(spacing: 6) {
                if item.state == .invisible {
                    Button {
                        onOpenDocument()
                    } label: {
                        Label("Document", systemImage: "doc.richtext")
                    }
                }
                Button {
                    LensFidelityDisclosureExporter.copy(item)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                Button {
                    LensFidelityDisclosureExporter.export(item)
                } label: {
                    Label(item.exportActionLabel, systemImage: "square.and.arrow.down")
                }
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    @ViewBuilder
    private func previewView(_ preview: LensFidelityPreview) -> some View {
        switch preview {
        case .chart(let chart):
            LensFidelityChartPreviewView(chart: chart)
                .frame(height: 96)
        case .table(let headers, let rows):
            VStack(alignment: .leading, spacing: 4) {
                Text(headers.joined(separator: "  |  "))
                    .font(.caption.weight(.semibold))
                ForEach(Array(rows.prefix(3).enumerated()), id: \.offset) { _, row in
                    Text(row.joined(separator: "  |  "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .textSelection(.enabled)
        case .transcript(let title, let reference):
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption.weight(.semibold))
                Text(reference)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .textSelection(.enabled)
        case .reference(let kind, let title, let reference):
            VStack(alignment: .leading, spacing: 3) {
                Text("\(kind): \(title)")
                    .font(.caption.weight(.semibold))
                Text(reference)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .textSelection(.enabled)
        case .markdown(let text), .raw(let text):
            Text(text)
                .font(.caption.monospaced())
                .lineLimit(4)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }
}

private struct LensFidelityChartPreviewView: View {
    let chart: LensFidelityChartPreview

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(chart.title)
                .font(.caption.weight(.semibold))
            Text(chart.provenance)
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
            Canvas { context, size in
                let frame = CGRect(
                    x: 8,
                    y: 4,
                    width: max(CGFloat(1), size.width - 16),
                    height: max(CGFloat(1), size.height - 16)
                )
                var axis = Path()
                axis.move(to: CGPoint(x: frame.minX, y: frame.maxY))
                axis.addLine(to: CGPoint(x: frame.maxX, y: frame.maxY))
                axis.move(to: CGPoint(x: frame.minX, y: frame.minY))
                axis.addLine(to: CGPoint(x: frame.minX, y: frame.maxY))
                context.stroke(axis, with: .color(.secondary.opacity(0.55)), lineWidth: 1)

                if chart.kind == "bar" {
                    drawBars(in: frame, context: &context)
                } else {
                    drawPoints(in: frame, context: &context)
                }
            }
        }
    }

    private func drawBars(in frame: CGRect, context: inout GraphicsContext) {
        let maxY = max(chart.points.map(\.y).max() ?? 1, 1)
        let width = frame.width / CGFloat(max(chart.points.count, 1)) * 0.66
        for (index, point) in chart.points.enumerated() {
            let height = frame.height * CGFloat(point.y / maxY)
            let x = frame.minX + CGFloat(index) * (frame.width / CGFloat(max(chart.points.count, 1))) + width * 0.25
            let rect = CGRect(x: x, y: frame.maxY - height, width: width, height: max(CGFloat(2), height))
            context.fill(Path(roundedRect: rect, cornerRadius: 3), with: .color(.accentColor))
        }
    }

    private func drawPoints(in frame: CGRect, context: inout GraphicsContext) {
        let xs = chart.points.map(\.x)
        let ys = chart.points.map(\.y)
        let xDomain = domain(xs)
        let yDomain = domain(ys)
        let projected = chart.points
            .sorted { chart.kind == "line" ? $0.x < $1.x : $0.label < $1.label }
            .map { point in
                CGPoint(
                    x: scale(point.x, from: xDomain, start: frame.minX, end: frame.maxX),
                    y: scale(point.y, from: yDomain, start: frame.maxY, end: frame.minY)
                )
            }

        if chart.kind == "line", let first = projected.first {
            var line = Path()
            line.move(to: first)
            for point in projected.dropFirst() {
                line.addLine(to: point)
            }
            context.stroke(line, with: .color(.accentColor), lineWidth: 2)
        }

        for point in projected {
            let rect = CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6)
            context.fill(Path(ellipseIn: rect), with: .color(.accentColor))
        }
    }

    private func domain(_ values: [Double]) -> ClosedRange<Double> {
        guard let minValue = values.min(),
              let maxValue = values.max()
        else { return 0...1 }
        if minValue == maxValue {
            return (minValue - 1)...(maxValue + 1)
        }
        return minValue...maxValue
    }

    private func scale(_ value: Double, from domain: ClosedRange<Double>, start: CGFloat, end: CGFloat) -> CGFloat {
        let denominator = domain.upperBound - domain.lowerBound
        guard denominator != 0 else { return start }
        let fraction = (value - domain.lowerBound) / denominator
        return start + CGFloat(fraction) * (end - start)
    }
}

private enum KeyValueReferenceParser {
    static func value(for key: String, in source: String) -> String? {
        let escaped = NSRegularExpression.escapedPattern(for: key)
        return capture(#"\b\#(escaped)\s*=\s*"([^"]*)""#, in: source)
            ?? capture(#"\b\#(escaped)\s*=\s*([^\s"}]+)"#, in: source)
    }

    private static func capture(_ pattern: String, in source: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(source.startIndex..<source.endIndex, in: source)
        guard let match = regex.firstMatch(in: source, range: range),
              match.numberOfRanges > 1,
              let valueRange = Range(match.range(at: 1), in: source)
        else { return nil }
        return String(source[valueRange])
    }
}
