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
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
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
                withAnimation(.smooth(duration: 0.2)) { expanded.toggle() }
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

    static func saveToFile(_ artifact: Artifact, convertTo: ArtifactKind? = nil) {
        let targetKind = convertTo ?? artifact.kind
        let content: String

        if let convertTo, convertTo != artifact.kind {
            content = convert(artifact.content, from: artifact.kind, to: convertTo)
        } else {
            content = artifact.content
        }

        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(sanitizeFilename(artifact.title)).\(targetKind.fileExtension)"
        panel.allowedContentTypes = [utType(for: targetKind)]
        panel.canCreateDirectories = true

        if panel.runModal() == .OK, let url = panel.url {
            try? content.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    // MARK: - Conversion

    private static func convert(_ content: String, from: ArtifactKind, to: ArtifactKind) -> String {
        switch (from, to) {
        case (.json, .yaml):
            return jsonToYAML(content)
        default:
            return content
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

    private static func utType(for kind: ArtifactKind) -> UTType {
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
