// ArtifactBlockView.swift
//
// Interactive card for rendering structured artifacts (JSON, YAML, code,
// tables, CSV) extracted from cloud model responses. Supports expand/
// collapse, copy to clipboard with proper UTTypes, and file export.
//
// Phase 4 of cloud artifact pipeline (2026-04-06).

import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Artifact Block

struct ArtifactBlockView: View {
    let artifact: Artifact

    @Environment(UIState.self) private var ui
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("epistemos.chat.artifactDocumentPresentationMode")
    private var documentPresentationModeRaw = MarkdownDocumentPresentationMode.rendered.rawValue

    @State private var expanded = true
    @State private var copied = false

    private var theme: EpistemosTheme { ui.theme }

    private var documentPresentationMode: MarkdownDocumentPresentationMode {
        get { MarkdownDocumentPresentationMode(rawValue: documentPresentationModeRaw) ?? .rendered }
        nonmutating set { documentPresentationModeRaw = newValue.rawValue }
    }

    private var documentPresentationModeBinding: Binding<MarkdownDocumentPresentationMode> {
        Binding(
            get: { documentPresentationMode },
            set: { documentPresentationMode = $0 }
        )
    }

    private var supportsDocumentToggle: Bool {
        switch artifact.kind {
        case .csv, .table, .markdown:
            true
        default:
            false
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if expanded {
                Divider().opacity(0.15)
                contentBody
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(.primary.opacity(0.08), lineWidth: 1)
        )
        .onAppear {
            if artifact.lineCount > 80 { expanded = false }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: artifact.kind.systemImage)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tint)

            Text(artifact.title)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)

            if let lang = artifact.language, artifact.kind == .codeBlock {
                Text(lang)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
            }

            Spacer()

            if supportsDocumentToggle {
                MarkdownDocumentModeToggle(mode: documentPresentationModeBinding)
            }

            Text("\(artifact.lineCount) lines")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)

            Button {
                ArtifactExporter.copyToClipboard(artifact)
                copied = true
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(1500))
                    copied = false
                }
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(copied ? .green : .secondary)
            }
            .buttonStyle(.plain)
            .help("Copy to clipboard")

            Menu {
                Button("Save as \(artifact.kind.fileExtension.uppercased())...") {
                    ArtifactExporter.saveToFile(artifact)
                }
                if artifact.kind == .json {
                    Button("Save as YAML...") {
                        ArtifactExporter.saveToFile(artifact, convertTo: .yaml)
                    }
                }
                // Per RCA13 RCA2-P1-003 follow-up 2026-05-11: real
                // MiniYAMLParser landed in ArtifactExporter so the
                // YAML→JSON path produces parseable output for the
                // YAML subset our chat artifacts emit. Restoring the
                // button.
                if artifact.kind == .yaml {
                    Button("Save as JSON...") {
                        ArtifactExporter.saveToFile(artifact, convertTo: .json)
                    }
                }
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .menuStyle(.borderlessButton)
            .help("Export artifact")

            Button {
                withAnimation(reduceMotion ? nil : .smooth(duration: 0.2)) { expanded.toggle() }
            } label: {
                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Content Body

    @ViewBuilder
    private var contentBody: some View {
        switch artifact.kind {
        case .json, .yaml, .codeBlock:
            codeContent
        case .csv:
            if documentPresentationMode == .rendered {
                csvContent
            } else {
                rawSourceContent
            }
        case .table:
            if documentPresentationMode == .rendered {
                tableContent
            } else {
                rawSourceContent
            }
        case .markdown:
            if documentPresentationMode == .rendered {
                markdownContent
            } else {
                rawSourceContent
            }
        case .fileEdit:
            codeContent // File edit diffs use code-style rendering
        }
    }

    private var codeContent: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Text(artifact.content)
                .font(.system(size: 12, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxHeight: 400)
    }

    private var csvContent: some View {
        let rows = artifact.content.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    csvRow(row, isHeader: index == 0)
                    if index == 0 { Divider().opacity(0.2) }
                }
            }
        }
        .frame(maxHeight: 300)
    }

    private func csvRow(_ row: String, isHeader: Bool) -> some View {
        let cells = row.components(separatedBy: ",")
        return HStack(spacing: 0) {
            ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                Text(cell.trimmingCharacters(in: .whitespaces))
                    .font(.system(size: 11, weight: isHeader ? .semibold : .regular,
                                  design: isHeader ? .default : .monospaced))
                    .foregroundStyle(isHeader ? .primary : .secondary)
                    .frame(minWidth: 60, alignment: .leading)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
            }
        }
    }

    private var tableContent: some View {
        let rows = artifact.content.components(separatedBy: .newlines)
            .filter { row in
                let trimmed = row.trimmingCharacters(in: .whitespaces)
                return !trimmed.isEmpty && !trimmed.allSatisfy { "|-: ".contains($0) }
            }
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 1) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    tableRow(row, isHeader: index == 0)
                }
            }
        }
        .frame(maxHeight: 300)
    }

    private func tableRow(_ row: String, isHeader: Bool) -> some View {
        let cells = row.split(separator: "|")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return HStack(spacing: 0) {
            ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                Text(cell)
                    .font(.system(size: 11, weight: isHeader ? .semibold : .regular))
                    .foregroundStyle(isHeader ? .primary : .secondary)
                    .frame(minWidth: 60, alignment: .leading)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
            }
        }
        .background(isHeader ? Color.primary.opacity(0.04) : .clear)
    }

    private var markdownContent: some View {
        TaggedMarkdownTextView(
            content: artifact.content,
            theme: theme,
            rippleStyle: .none,
            typographyRole: .assistant
        )
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var rawSourceContent: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Text(artifact.content)
                .font(.system(size: 12, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxHeight: 400)
    }
}

// MARK: - Artifact Exporter

@MainActor
enum ArtifactExporter {
    static func copyToClipboard(_ artifact: Artifact) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(artifact.content, forType: .string)
    }

    static func saveToFile(_ artifact: Artifact, convertTo: ChatArtifactKind? = nil) {
        let targetKind = convertTo ?? artifact.kind
        let content: String

        if let convertTo, convertTo != artifact.kind {
            content = convert(artifact.content, from: artifact.kind, to: convertTo)
        } else {
            content = artifact.content
        }

        ChatTextExportSupport.save(
            content,
            suggestedFilename: "\(sanitizeFilename(artifact.title)).\(targetKind.fileExtension)",
            contentType: utType(for: targetKind)
        )
    }

    // MARK: - Conversion

    private static func convert(_ content: String, from: ChatArtifactKind, to: ChatArtifactKind) -> String {
        switch (from, to) {
        case (.json, .yaml):
            return jsonToYAML(content)
        case (.yaml, .json):
            return yamlToJSON(content)
        default:
            return content
        }
    }

    /// Parse the YAML subset we emit + serialize it back as JSON.
    /// Handles block-style mappings, lists, scalars (string / bool /
    /// number / null), and multi-line literal blocks (`|`). Sufficient
    /// for round-tripping the output of `jsonToYAML` and the typical
    /// YAML artifacts the chat produces. Falls back to the original
    /// string if parsing fails so the user always gets *something*
    /// in the file.
    private static func yamlToJSON(_ yaml: String) -> String {
        var parser = MiniYAMLParser(source: yaml)
        guard let parsed = parser.parseDocument() else { return yaml }
        do {
            let data = try JSONSerialization.data(
                withJSONObject: parsed,
                options: [.prettyPrinted, .sortedKeys]
            )
            return String(data: data, encoding: .utf8) ?? yaml
        } catch {
            return yaml
        }
    }

    private static func jsonToYAML(_ json: String) -> String {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) else {
            return json
        }
        return yamlString(from: obj, indent: 0)
    }

    private static func yamlString(from value: Any, indent: Int) -> String {
        let prefix = String(repeating: "  ", count: indent)
        if let dict = value as? [String: Any] {
            if dict.isEmpty { return "{}" }
            return dict.sorted(by: { $0.key < $1.key }).map { key, val in
                if let nested = val as? [String: Any], !nested.isEmpty {
                    return "\(prefix)\(key):\n\(yamlString(from: nested, indent: indent + 1))"
                } else if let arr = val as? [Any], !arr.isEmpty {
                    return "\(prefix)\(key):\n\(yamlString(from: arr, indent: indent + 1))"
                } else {
                    return "\(prefix)\(key): \(yamlScalar(val))"
                }
            }.joined(separator: "\n")
        } else if let arr = value as? [Any] {
            return arr.map { item in
                if let dict = item as? [String: Any] {
                    let inner = yamlString(from: dict, indent: indent + 1)
                    return "\(prefix)-\n\(inner)"
                } else {
                    return "\(prefix)- \(yamlScalar(item))"
                }
            }.joined(separator: "\n")
        } else {
            return "\(prefix)\(yamlScalar(value))"
        }
    }

    private static func yamlScalar(_ value: Any) -> String {
        switch value {
        case is NSNull: return "null"
        case let b as Bool: return b ? "true" : "false"
        case let n as NSNumber: return "\(n)"
        case let s as String:
            if s.contains("\n") || s.contains(":") || s.contains("#") {
                return "|\n  " + s.replacingOccurrences(of: "\n", with: "\n  ")
            }
            return s.contains("\"") ? "'\(s)'" : s
        default: return "\(value)"
        }
    }

    // MARK: - Helpers

    private static func utType(for kind: ChatArtifactKind) -> UTType {
        switch kind {
        case .json: return .json
        case .yaml: return .yaml
        case .csv: return .commaSeparatedText
        case .codeBlock: return .sourceCode
        case .table: return .commaSeparatedText
        case .markdown: return .plainText
        case .fileEdit: return .plainText
        }
    }

    private static func sanitizeFilename(_ title: String) -> String {
        let cleaned = title
            .replacingOccurrences(of: "[^a-zA-Z0-9_\\- ]", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: " ", with: "-")
            .lowercased()
        return cleaned.isEmpty ? "artifact" : String(cleaned.prefix(50))
    }
}

// MARK: - Mini YAML parser
//
// Reads the flat-block YAML subset that `ArtifactExporter.jsonToYAML`
// emits + the typical YAML our chat artifacts ship. Supports:
//   - Block-style mappings (`key: value`, nested via indent)
//   - Block-style sequences (`- value`, `- \n  key: value`)
//   - Scalars: bool, integer, float, null, single-quoted string, plain string
//   - Multi-line literal scalars introduced by `|`
//   - Comments (`#` at start-of-line or after a space)
// Does NOT support: flow-style `[a, b]` / `{ a: b }`, anchors `&` / aliases `*`,
// folded scalars `>`, tags `!!str`, complex keys. The parser falls back to
// returning nil on anything it doesn't understand; the caller treats that as
// "leave the source string untouched."

private struct MiniYAMLParser {
    let lines: [String]
    var index: Int = 0

    init(source: String) {
        self.lines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }

    mutating func parseDocument() -> Any? {
        skipBlanksAndComments()
        guard index < lines.count else { return [:] }
        return parseValue(at: indentOf(lines[index]))
    }

    private mutating func skipBlanksAndComments() {
        while index < lines.count {
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                index += 1
            } else {
                break
            }
        }
    }

    private func indentOf(_ line: String) -> Int {
        var count = 0
        for ch in line {
            if ch == " " { count += 1 }
            else { break }
        }
        return count
    }

    private mutating func parseValue(at indent: Int) -> Any? {
        skipBlanksAndComments()
        guard index < lines.count else { return nil }
        let line = lines[index]
        let lineIndent = indentOf(line)
        if lineIndent < indent { return nil }
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("- ") || trimmed == "-" {
            return parseSequence(at: lineIndent)
        }
        if trimmed.contains(":") {
            return parseMapping(at: lineIndent)
        }
        // Bare scalar — single-line.
        index += 1
        return scalar(from: trimmed)
    }

    private mutating func parseMapping(at indent: Int) -> [String: Any] {
        var result: [String: Any] = [:]
        while index < lines.count {
            skipBlanksAndComments()
            guard index < lines.count else { break }
            let line = lines[index]
            let lineIndent = indentOf(line)
            if lineIndent < indent { break }
            if lineIndent > indent {
                // Trailing over-indented orphan — bail.
                break
            }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard let colon = trimmed.firstIndex(of: ":") else { break }
            let key = String(trimmed[..<colon]).trimmingCharacters(in: .whitespaces)
            let after = trimmed.index(after: colon)
            let valuePart = String(trimmed[after...]).trimmingCharacters(in: .whitespaces)
            index += 1
            if valuePart == "|" {
                result[key] = parseLiteralBlock(at: indent + 2)
            } else if valuePart.isEmpty {
                result[key] = parseValue(at: indent + 2) ?? [:]
            } else {
                result[key] = scalar(from: valuePart)
            }
        }
        return result
    }

    private mutating func parseSequence(at indent: Int) -> [Any] {
        var result: [Any] = []
        while index < lines.count {
            skipBlanksAndComments()
            guard index < lines.count else { break }
            let line = lines[index]
            let lineIndent = indentOf(line)
            if lineIndent < indent { break }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("- ") || trimmed == "-" else { break }
            if trimmed == "-" {
                // Block-form item, indented mapping on next lines.
                index += 1
                if let nested = parseValue(at: indent + 2) {
                    result.append(nested)
                }
            } else {
                let scalarPart = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                index += 1
                result.append(scalar(from: scalarPart))
            }
        }
        return result
    }

    private mutating func parseLiteralBlock(at indent: Int) -> String {
        var collected: [String] = []
        while index < lines.count {
            let line = lines[index]
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                collected.append("")
                index += 1
                continue
            }
            let lineIndent = indentOf(line)
            if lineIndent < indent { break }
            collected.append(String(line.dropFirst(min(indent, line.count))))
            index += 1
        }
        return collected.joined(separator: "\n")
    }

    private func scalar(from raw: String) -> Any {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return NSNull() }
        if trimmed == "null" || trimmed == "~" { return NSNull() }
        if trimmed == "true" { return true }
        if trimmed == "false" { return false }
        if let i = Int(trimmed) { return i }
        if let d = Double(trimmed) { return d }
        // Single-quoted: strip + un-escape the duplicated single quote.
        if trimmed.hasPrefix("'") && trimmed.hasSuffix("'") && trimmed.count >= 2 {
            let inner = String(trimmed.dropFirst().dropLast())
            return inner.replacingOccurrences(of: "''", with: "'")
        }
        // Double-quoted: strip + un-escape \n, \", \\.
        if trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"") && trimmed.count >= 2 {
            let inner = String(trimmed.dropFirst().dropLast())
            return inner
                .replacingOccurrences(of: "\\\\", with: "\\")
                .replacingOccurrences(of: "\\\"", with: "\"")
                .replacingOccurrences(of: "\\n", with: "\n")
        }
        return trimmed
    }
}
