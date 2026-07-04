import Foundation
import SwiftData

struct GooseAppContextSnapshot: Codable, Equatable, Sendable {
    struct Note: Codable, Equatable, Sendable {
        var id: String
        var title: String
        var path: String?
        var vaultRelativePath: String?
        var preview: String?
        var wordCount: Int
    }

    struct Graph: Codable, Equatable, Sendable {
        var route: String
        var sourceId: String?
        var selectedNodeId: String?
        var selectedNodeTitle: String?
        var selectedNodeType: String?
        var selectedNodeSourceId: String?
    }

    struct Attachment: Codable, Equatable, Sendable {
        var kind: String
        var title: String
        var path: String?
        var targetId: String?
        var summary: String?
    }

    static let maxPathCharacters = 1_024
    static let maxTitleCharacters = 240
    static let maxPreviewCharacters = 600
    static let maxPromptContextCharacters = 2_000

    var available: Bool
    var source: String
    var appMode: String
    var capturedAt: String
    var vaultPath: String?
    var activeNote: Note?
    var graph: Graph?
    var attachments: [Attachment]
    var promptContext: String?

    init(
        available: Bool = false,
        source: String = "epistemos",
        appMode: String = "goose",
        capturedAt: String = Self.isoTimestamp(),
        vaultPath: String? = nil,
        activeNote: Note? = nil,
        graph: Graph? = nil,
        attachments: [Attachment] = [],
        promptContext: String? = nil
    ) {
        self.available = available
        self.source = Self.clean(source, limit: 80) ?? "epistemos"
        self.appMode = Self.clean(appMode, limit: 80) ?? "goose"
        self.capturedAt = Self.clean(capturedAt, limit: 80) ?? Self.isoTimestamp()
        self.vaultPath = Self.clean(vaultPath, limit: Self.maxPathCharacters)
        self.activeNote = Self.sanitized(note: activeNote)
        self.graph = Self.sanitized(graph: graph)
        self.attachments = attachments.prefix(8).map { Self.sanitized(attachment: $0) }
        self.promptContext = Self.clean(promptContext, limit: Self.maxPromptContextCharacters)
    }

    @MainActor
    static func current(bootstrap: AppBootstrap? = AppBootstrap.shared) async -> GooseAppContextSnapshot {
        guard let bootstrap else {
            return GooseAppContextSnapshot(promptContext: "No Epistemos app context is available yet.")
        }

        let activeNote = await activeNoteSnapshot(
            pageId: bootstrap.notesUI.activePageId,
            bootstrap: bootstrap
        )
        let graph = graphSnapshot(from: bootstrap.graphState)
        var attachments: [Attachment] = []
        if let activeNote {
            attachments.append(Attachment(
                kind: "note",
                title: activeNote.title,
                path: activeNote.path ?? activeNote.vaultRelativePath,
                targetId: activeNote.id,
                summary: activeNote.preview
            ))
        }
        if let graph,
           let nodeId = graph.selectedNodeId,
           let title = graph.selectedNodeTitle {
            attachments.append(Attachment(
                kind: "graph",
                title: title,
                path: nil,
                targetId: graph.selectedNodeSourceId ?? nodeId,
                summary: "Graph \(graph.route)"
            ))
        }

        let vaultPath = bootstrap.vaultSync.vaultURL?.standardizedFileURL.path
        let promptContext = promptContextText(
            vaultPath: vaultPath,
            activeNote: activeNote,
            graph: graph
        )
        return GooseAppContextSnapshot(
            available: vaultPath != nil || activeNote != nil || graph != nil,
            vaultPath: vaultPath,
            activeNote: activeNote,
            graph: graph,
            attachments: attachments,
            promptContext: promptContext
        )
    }

    var dictionary: [String: Any] {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(self),
              let object = try? JSONSerialization.jsonObject(with: data),
              let dictionary = object as? [String: Any] else {
            return [
                "available": false,
                "source": "epistemos",
                "appMode": "goose",
                "capturedAt": Self.isoTimestamp(),
                "attachments": [],
                "promptContext": "Epistemos failed to serialize the current context snapshot.",
            ]
        }
        return dictionary
    }

    private static func activeNoteSnapshot(
        pageId: String?,
        bootstrap: AppBootstrap
    ) async -> Note? {
        guard let pageId = clean(pageId, limit: maxTitleCharacters) else { return nil }
        var descriptor = FetchDescriptor<SDPage>(
            predicate: #Predicate<SDPage> { $0.id == pageId }
        )
        descriptor.fetchLimit = 1
        guard let page = try? bootstrap.modelContainer.mainContext.fetch(descriptor).first else {
            return Note(
                id: pageId,
                title: pageId,
                path: nil,
                vaultRelativePath: nil,
                preview: nil,
                wordCount: 0
            )
        }
        let body: String
        if let liveBody = NoteWindowManager.shared.editorBody(for: page.id) {
            body = liveBody
        } else {
            let readPageId = page.id
            body = await Task.detached(priority: .utility) {
                NoteFileStorage.readBody(pageId: readPageId, mapped: true, fast: false)
            }.value
        }
        return Note(
            id: page.id,
            title: clean(page.title, limit: maxTitleCharacters) ?? page.id,
            path: clean(page.filePath, limit: maxPathCharacters),
            vaultRelativePath: clean(page.vaultRelativeNotePath, limit: maxPathCharacters),
            preview: compactPreview(body, limit: maxPreviewCharacters),
            wordCount: max(0, page.wordCount)
        )
    }

    private static func sanitized(note: Note?) -> Note? {
        guard let note else { return nil }
        let fallbackID = clean(note.id, limit: maxTitleCharacters) ?? "note"
        return Note(
            id: fallbackID,
            title: clean(note.title, limit: maxTitleCharacters) ?? fallbackID,
            path: clean(note.path, limit: maxPathCharacters),
            vaultRelativePath: clean(note.vaultRelativePath, limit: maxPathCharacters),
            preview: clean(note.preview, limit: maxPreviewCharacters),
            wordCount: max(0, note.wordCount)
        )
    }

    private static func graphSnapshot(from graphState: GraphState) -> Graph? {
        let route = graphState.currentRoute.serializationKey
        let sourceId: String?
        switch graphState.currentRoute {
        case .canvas:
            sourceId = nil
        case .note(let id), .folder(let id):
            sourceId = id
        }
        guard graphState.currentRoute != .canvas || graphState.selectedNodeId != nil else {
            return nil
        }
        let selectedNode = graphState.selectedNode
        return Graph(
            route: route,
            sourceId: clean(sourceId, limit: maxTitleCharacters),
            selectedNodeId: clean(graphState.selectedNodeId, limit: maxTitleCharacters),
            selectedNodeTitle: clean(selectedNode?.label, limit: maxTitleCharacters),
            selectedNodeType: clean(selectedNode?.type.rawValue, limit: 80),
            selectedNodeSourceId: clean(selectedNode?.sourceId, limit: maxTitleCharacters)
        )
    }

    private static func sanitized(graph: Graph?) -> Graph? {
        guard let graph else { return nil }
        return Graph(
            route: clean(graph.route, limit: maxTitleCharacters) ?? "canvas",
            sourceId: clean(graph.sourceId, limit: maxTitleCharacters),
            selectedNodeId: clean(graph.selectedNodeId, limit: maxTitleCharacters),
            selectedNodeTitle: clean(graph.selectedNodeTitle, limit: maxTitleCharacters),
            selectedNodeType: clean(graph.selectedNodeType, limit: 80),
            selectedNodeSourceId: clean(graph.selectedNodeSourceId, limit: maxTitleCharacters)
        )
    }

    private static func sanitized(attachment: Attachment) -> Attachment {
        let kind = clean(attachment.kind, limit: 80) ?? "context"
        return Attachment(
            kind: kind,
            title: clean(attachment.title, limit: maxTitleCharacters) ?? kind,
            path: clean(attachment.path, limit: maxPathCharacters),
            targetId: clean(attachment.targetId, limit: maxTitleCharacters),
            summary: clean(attachment.summary, limit: maxPreviewCharacters)
        )
    }

    private static func promptContextText(
        vaultPath: String?,
        activeNote: Note?,
        graph: Graph?
    ) -> String? {
        var lines: [String] = []
        lines.append("Epistemos context snapshot:")
        if let vaultPath = clean(vaultPath, limit: maxPathCharacters) {
            lines.append("- Vault: \(vaultPath)")
        }
        if let activeNote {
            lines.append("- Active note: \(activeNote.title)")
            if let path = activeNote.path ?? activeNote.vaultRelativePath {
                lines.append("  Path: \(path)")
            }
            if let preview = activeNote.preview {
                lines.append("  Preview: \(preview)")
            }
        }
        if let graph {
            lines.append("- Graph route: \(graph.route)")
            if let title = graph.selectedNodeTitle {
                lines.append("  Selected node: \(title)")
            } else if let selectedNodeId = graph.selectedNodeId {
                lines.append("  Selected node: \(selectedNodeId)")
            }
        }
        guard lines.count > 1 else { return nil }
        return clean(lines.joined(separator: "\n"), limit: maxPromptContextCharacters)
    }

    private static func compactPreview(_ value: String, limit: Int) -> String? {
        let collapsed = value
            .replacingOccurrences(of: "\n", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !collapsed.isEmpty else { return nil }
        return clean(collapsed, limit: limit)
    }

    private static func clean(_ value: String?, limit: Int) -> String? {
        let leadingTrimmed = (value ?? "").drop { character in
            character.unicodeScalars.allSatisfy { CharacterSet.whitespacesAndNewlines.contains($0) }
        }
        let bounded = String(leadingTrimmed.prefix(limit + 32))
        let trimmed = bounded.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard limit > 3, trimmed.count > limit else { return trimmed }
        return String(trimmed.prefix(limit - 3)) + "..."
    }

    private static func isoTimestamp(date: Date = Date()) -> String {
        ISO8601DateFormatter().string(from: date)
    }
}
