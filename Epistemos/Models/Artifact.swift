// Artifact.swift
//
// Data model for structured artifacts extracted from cloud model responses.
// Artifacts are rich content blocks (JSON, YAML, code, tables) that the
// app can render interactively, export to files, and copy with proper
// UTTypes. Stored alongside messages in SDMessage.artifactsData.
//
// Phase 3 of cloud artifact pipeline (2026-04-06).

import Foundation

// MARK: - Artifact Kind

nonisolated enum ArtifactKind: String, Codable, Sendable, CaseIterable {
    case json
    case yaml
    case csv
    case codeBlock
    case table
    case markdown

    var displayName: String {
        switch self {
        case .json: "JSON"
        case .yaml: "YAML"
        case .csv: "CSV"
        case .codeBlock: "Code"
        case .table: "Table"
        case .markdown: "Markdown"
        }
    }

    var systemImage: String {
        switch self {
        case .json: "curlybraces"
        case .yaml: "doc.text"
        case .csv: "tablecells"
        case .codeBlock: "chevron.left.forwardslash.chevron.right"
        case .table: "tablecells.badge.ellipsis"
        case .markdown: "doc.richtext"
        }
    }

    var fileExtension: String {
        switch self {
        case .json: "json"
        case .yaml: "yaml"
        case .csv: "csv"
        case .codeBlock: "txt"
        case .table: "csv"
        case .markdown: "md"
        }
    }
}

// MARK: - Artifact

nonisolated struct Artifact: Identifiable, Codable, Sendable {
    let id: String
    let kind: ArtifactKind
    let title: String
    let language: String?
    let content: String
    let schemaName: String?
    let createdAt: Date

    init(
        id: String = UUID().uuidString,
        kind: ArtifactKind,
        title: String,
        language: String? = nil,
        content: String,
        schemaName: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.language = language
        self.content = content
        self.schemaName = schemaName
        self.createdAt = createdAt
    }

    /// Line count of the content (for UI collapse decisions).
    var lineCount: Int {
        content.components(separatedBy: .newlines).count
    }
}
