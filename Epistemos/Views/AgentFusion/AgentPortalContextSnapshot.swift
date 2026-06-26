import Foundation

/// Epistemos-owned context carried by every agent portal.
///
/// This is the shared session/context spine for Landing now and for Mini, Note,
/// and Graph portals later. It intentionally stays as bounded value data so old
/// chat surfaces do not return as parallel engines.
struct AgentPortalContextSnapshot: Codable, Equatable, Sendable {
    enum Portal: String, Codable, CaseIterable, Sendable {
        case main
        case landing
        case mini
        case note
        case graph
        case vault

        var label: String {
            switch self {
            case .main: "Main"
            case .landing: "Landing"
            case .mini: "Mini"
            case .note: "Note"
            case .graph: "Graph"
            case .vault: "Vault"
            }
        }
    }

    struct NoteContext: Codable, Equatable, Sendable {
        var pageId: String
        var title: String?
        var path: String?
        var selectedText: String?
        var visibleExcerpt: String?
        var backlinks: [String]
        var tags: [String]
    }

    struct GraphContext: Codable, Equatable, Sendable {
        var route: String?
        var selectedNodeIds: [String]
        var selectedEdgeIds: [String]
        var neighborhoodSummary: String?
        var approvedActions: [String]
    }

    struct VaultContext: Codable, Equatable, Sendable {
        var rootPath: String?
        var workspacePath: String?
        var storageSummary: String?
        var approvedActions: [String]
    }

    struct ActionDescriptor: Codable, Equatable, Sendable {
        var id: String
        var title: String
        var summary: String
        var portalScopes: [Portal]
        var requiresApproval: Bool
        var mutatesAppState: Bool
        var resourceURI: String?
    }

    var portal: Portal
    var title: String?
    var sessionId: String?
    var promptPreview: String?
    var note: NoteContext?
    var graph: GraphContext?
    var vault: VaultContext?
    var approvedActions: [String]
    var additionalContextAttachments: [ContextAttachment]

    init(
        portal: Portal,
        title: String? = nil,
        sessionId: String? = nil,
        promptPreview: String? = nil,
        note: NoteContext? = nil,
        graph: GraphContext? = nil,
        vault: VaultContext? = nil,
        approvedActions: [String] = [],
        additionalContextAttachments: [ContextAttachment] = []
    ) {
        self.portal = portal
        self.title = Self.normalized(title, limit: 120)
        self.sessionId = Self.normalized(sessionId, limit: 96)
        self.promptPreview = Self.normalized(promptPreview, limit: 240)
        self.note = note.map(Self.normalizedNote)
        self.graph = graph.map(Self.normalizedGraph)
        self.vault = vault.map(Self.normalizedVault)
        self.approvedActions = Self.normalizedList(approvedActions, limit: 12, itemLimit: 80)
        self.additionalContextAttachments = Self.normalizedAttachments(
            additionalContextAttachments,
            limit: 12
        )
    }

    static func main(
        sessionId: String? = nil,
        vaultRootPath: String?,
        workspacePath: String?
    ) -> AgentPortalContextSnapshot {
        AgentPortalContextSnapshot(
            portal: .main,
            title: "Main agent",
            sessionId: sessionId,
            vault: VaultContext(
                rootPath: vaultRootPath,
                workspacePath: workspacePath,
                storageSummary: "Epistemos app vault and workspace context",
                approvedActions: ["vault.search", "session.summary", "skill.discovery"]
            ),
            approvedActions: ["app-context.snapshot", "session.resume", "session.summary", "skill.discovery"]
        )
    }

    static func landing(
        prompt: String,
        sessionId: String? = nil,
        vaultRootPath: String?,
        workspacePath: String?
    ) -> AgentPortalContextSnapshot {
        AgentPortalContextSnapshot(
            portal: .landing,
            title: "Landing",
            sessionId: sessionId,
            promptPreview: prompt,
            vault: VaultContext(
                rootPath: vaultRootPath,
                workspacePath: workspacePath,
                storageSummary: "Landing-created session with vault-aware app context",
                approvedActions: [
                    "vault.search",
                    "note.create",
                    "note.update",
                    "app-context.snapshot",
                    "skill.discovery",
                    "session.summary",
                ]
            ),
            approvedActions: [
                "route.to.agent",
                "vault.search",
                "note.create",
                "note.update",
                "app-context.snapshot",
                "skill.discovery",
                "session.summary",
            ]
        )
    }

    static func mini(
        vaultRootPath: String?,
        workspacePath: String?,
        sessionId: String? = nil,
        promptPreview: String? = nil,
        sourceTitle: String? = nil
    ) -> AgentPortalContextSnapshot {
        AgentPortalContextSnapshot(
            portal: .mini,
            title: sourceTitle ?? "Mini agent",
            sessionId: sessionId,
            promptPreview: promptPreview,
            vault: VaultContext(
                rootPath: vaultRootPath,
                workspacePath: workspacePath,
                storageSummary: "Compact portal into the shared Epistemos agent session",
                approvedActions: ["vault.search", "app-context.snapshot", "session.summary", "skill.discovery"]
            ),
            approvedActions: [
                "session.resume",
                "vault.search",
                "app-context.snapshot",
                "session.summary",
                "skill.discovery",
            ]
        )
    }

    static func note(
        pageId: String,
        vaultRootPath: String?,
        workspacePath: String?,
        sessionId: String? = nil,
        title: String? = nil,
        path: String? = nil,
        selectedText: String? = nil,
        visibleExcerpt: String? = nil,
        backlinks: [String] = [],
        tags: [String] = []
    ) -> AgentPortalContextSnapshot {
        AgentPortalContextSnapshot(
            portal: .note,
            title: title ?? "Note agent",
            sessionId: sessionId,
            note: NoteContext(
                pageId: pageId,
                title: title,
                path: path,
                selectedText: selectedText,
                visibleExcerpt: visibleExcerpt,
                backlinks: backlinks,
                tags: tags
            ),
            vault: VaultContext(
                rootPath: vaultRootPath,
                workspacePath: workspacePath,
                storageSummary: "Note-scoped portal with approved vault and note actions",
                approvedActions: [
                    "vault.search",
                    "note.read",
                    "note.update",
                    "note.rewrite-selection",
                    "note.delete.with-approval",
                ]
            ),
            approvedActions: [
                "note.read",
                "note.update",
                "note.rewrite-selection",
                "note.delete.with-approval",
                "vault.search",
                "app-context.snapshot",
                "session.summary",
                "skill.discovery",
            ]
        )
    }

    static func graph(
        vaultRootPath: String?,
        workspacePath: String?,
        sessionId: String? = nil,
        route: String? = nil,
        selectedNodeIds: [String] = [],
        selectedEdgeIds: [String] = [],
        neighborhoodSummary: String? = nil
    ) -> AgentPortalContextSnapshot {
        AgentPortalContextSnapshot(
            portal: .graph,
            title: "Graph agent",
            sessionId: sessionId,
            graph: GraphContext(
                route: route,
                selectedNodeIds: selectedNodeIds,
                selectedEdgeIds: selectedEdgeIds,
                neighborhoodSummary: neighborhoodSummary,
                approvedActions: [
                    "graph.read",
                    "graph.neighborhood",
                    "graph.mutate.with-approval",
                ]
            ),
            vault: VaultContext(
                rootPath: vaultRootPath,
                workspacePath: workspacePath,
                storageSummary: "Graph-scoped portal with selected nodes, edges, and route context",
                approvedActions: ["vault.search", "graph.read", "graph.neighborhood", "app-context.snapshot"]
            ),
            approvedActions: [
                "graph.read",
                "graph.neighborhood",
                "graph.mutate.with-approval",
                "vault.search",
                "app-context.snapshot",
                "session.summary",
                "skill.discovery",
            ]
        )
    }

    func withSessionId(_ sessionId: String) -> AgentPortalContextSnapshot {
        var copy = self
        copy.sessionId = Self.normalized(sessionId, limit: 96)
        return copy
    }

    func withAdditionalContextAttachments(_ attachments: [ContextAttachment]) -> AgentPortalContextSnapshot {
        var copy = self
        copy.additionalContextAttachments = Self.normalizedAttachments(attachments, limit: 12)
        return copy
    }

    var bridgePresentation: String {
        var parts = [portal.label]
        if let sessionId {
            parts.append("session: \(String(sessionId.prefix(8)))")
        }
        if let title {
            parts.append("title: \(title)")
        }
        if !approvedActions.isEmpty {
            parts.append("actions: \(approvedActions.prefix(4).joined(separator: ","))")
        }
        if let note {
            parts.append("note: \(note.title ?? note.pageId)")
            if let selectedText = Self.normalized(note.selectedText, limit: 160) {
                parts.append("selected: \(selectedText)")
            } else if let visibleExcerpt = Self.normalized(note.visibleExcerpt, limit: 160) {
                parts.append("excerpt: \(visibleExcerpt)")
            }
            if !note.tags.isEmpty {
                parts.append("tags: \(note.tags.prefix(4).joined(separator: ","))")
            }
        }
        if let graph {
            if let route = graph.route {
                parts.append("graph: \(route)")
            }
            if !graph.selectedNodeIds.isEmpty {
                parts.append("nodes: \(graph.selectedNodeIds.prefix(4).joined(separator: ","))")
            }
            if !graph.selectedEdgeIds.isEmpty {
                parts.append("edges: \(graph.selectedEdgeIds.prefix(4).joined(separator: ","))")
            }
            if let summary = Self.normalized(graph.neighborhoodSummary, limit: 160) {
                parts.append("neighborhood: \(summary)")
            }
        }
        if !additionalContextAttachments.isEmpty {
            parts.append("context: \(additionalContextAttachments.map(\.title).prefix(4).joined(separator: ","))")
        }
        return parts.joined(separator: " | ")
    }

    var modelVisibleSummary: String {
        var parts = ["portal: \(portal.rawValue)"]
        if let sessionId {
            parts.append("session: \(sessionId)")
        }
        if let title {
            parts.append("title: \(title)")
        }
        if let vaultRoot = vault?.rootPath {
            parts.append("vault: \(vaultRoot)")
        }
        if let note {
            parts.append("note: \(note.title ?? note.pageId)")
            if let path = note.path {
                parts.append("notePath: \(path)")
            }
            if let selectedText = note.selectedText {
                parts.append("selectedText: \(selectedText)")
            }
            if let visibleExcerpt = note.visibleExcerpt {
                parts.append("visibleExcerpt: \(visibleExcerpt)")
            }
            if !note.backlinks.isEmpty {
                parts.append("backlinks: \(note.backlinks.joined(separator: ","))")
            }
            if !note.tags.isEmpty {
                parts.append("tags: \(note.tags.joined(separator: ","))")
            }
        }
        if let graphRoute = graph?.route {
            parts.append("graph: \(graphRoute)")
        }
        if let graph {
            if !graph.selectedNodeIds.isEmpty {
                parts.append("graphNodes: \(graph.selectedNodeIds.joined(separator: ","))")
            }
            if !graph.selectedEdgeIds.isEmpty {
                parts.append("graphEdges: \(graph.selectedEdgeIds.joined(separator: ","))")
            }
            if let neighborhoodSummary = graph.neighborhoodSummary {
                parts.append("neighborhood: \(neighborhoodSummary)")
            }
        }
        if !approvedActions.isEmpty {
            parts.append("approved: \(approvedActions.joined(separator: ","))")
        }
        if !additionalContextAttachments.isEmpty {
            parts.append("attachments: \(additionalContextAttachments.map(\.title).prefix(4).joined(separator: ","))")
        }
        return parts.joined(separator: " | ")
    }

    var modelVisibleJSON: String {
        Self.encodedJSONString(self)
    }

    var contextAttachments: [ContextAttachment] {
        var attachments: [ContextAttachment] = []

        if let vault {
            attachments.append(ContextAttachment(
                kind: .allNotes,
                targetId: vault.rootPath ?? "epistemos-vault",
                title: "Epistemos Vault",
                subtitle: vault.storageSummary ?? vault.rootPath,
                resourceURI: "epistemos://vault/root",
                resourceMode: .live,
                resourceCapabilities: vault.approvedActions
            ))
        }

        if let note {
            attachments.append(ContextAttachment(
                kind: .note,
                targetId: note.pageId,
                title: note.title ?? "Active note",
                subtitle: note.visibleExcerpt,
                resourceURI: "epistemos://note/\(note.pageId)",
                resourceMode: .live,
                resourceCapabilities: ["read", "update", "rewrite-selection"]
            ))
        }

        if let graph {
            let target = graph.route ?? graph.selectedNodeIds.first ?? "graph-context"
            attachments.append(ContextAttachment(
                kind: .graph,
                targetId: target,
                title: "Graph Context",
                subtitle: graph.neighborhoodSummary ?? graph.route,
                resourceURI: "epistemos://graph/context",
                resourceMode: .live,
                resourceCapabilities: graph.approvedActions
            ))
        }

        for attachment in additionalContextAttachments where !attachments.contains(where: { $0.id == attachment.id }) {
            attachments.append(attachment)
        }

        return attachments
    }

    var actionDescriptors: [ActionDescriptor] {
        let actionIDs = allApprovedActionIDs
        return Self.actionCatalog.filter { descriptor in
            actionIDs.contains(descriptor.id)
                || descriptor.portalScopes.contains(portal)
        }
    }

    func agentClonePromptEnvelope(
        userPrompt: String,
        capabilityLines: [String] = []
    ) -> String {
        let prompt = Self.normalized(userPrompt, limit: 4_000) ?? userPrompt
        let contextLines = agentClonePromptContextLines(capabilityLines: capabilityLines)
        guard !contextLines.isEmpty else { return prompt }
        let contextBlock = contextLines
            .prefix(20)
            .map { "- \($0)" }
            .joined(separator: "\n")
        return """
        Use this Epistemos portal context. Preserve the user's request as the task and use only approved app actions:
        \(contextBlock)

        User request:
        \(prompt)
        """
    }

    private func agentClonePromptContextLines(capabilityLines: [String]) -> [String] {
        var lines: [String] = [
            "portal: \(portal.label)",
        ]
        if let sessionId {
            lines.append("session: \(String(sessionId.prefix(8)))")
        }
        if let title {
            lines.append("title: \(title)")
        }
        if let vault {
            if let rootPath = vault.rootPath {
                lines.append("vault: \(Self.clippedPath(rootPath))")
            }
            if let workspacePath = vault.workspacePath {
                lines.append("workspace: \(Self.clippedPath(workspacePath))")
            }
            if let storageSummary = vault.storageSummary {
                lines.append("vault summary: \(Self.clippedInline(storageSummary, limit: 120))")
            }
        }
        if let note {
            lines.append("note: \(Self.clippedInline(note.title ?? note.pageId, limit: 80))")
            if let path = note.path {
                lines.append("note path: \(Self.clippedPath(path))")
            }
            if let selectedText = note.selectedText {
                lines.append("selection: \(Self.clippedInline(selectedText, limit: 160))")
            } else if let visibleExcerpt = note.visibleExcerpt {
                lines.append("excerpt: \(Self.clippedInline(visibleExcerpt, limit: 160))")
            }
            if !note.tags.isEmpty {
                lines.append("tags: \(note.tags.prefix(6).joined(separator: ","))")
            }
        }
        if let graph {
            if let route = graph.route {
                lines.append("graph: \(Self.clippedInline(route, limit: 80))")
            }
            if !graph.selectedNodeIds.isEmpty {
                lines.append("graph nodes: \(graph.selectedNodeIds.prefix(8).joined(separator: ","))")
            }
            if !graph.selectedEdgeIds.isEmpty {
                lines.append("graph edges: \(graph.selectedEdgeIds.prefix(8).joined(separator: ","))")
            }
            if let neighborhoodSummary = graph.neighborhoodSummary {
                lines.append("neighborhood: \(Self.clippedInline(neighborhoodSummary, limit: 160))")
            }
        }
        if !additionalContextAttachments.isEmpty {
            lines.append("attached: \(additionalContextAttachments.map(\.title).prefix(6).joined(separator: ","))")
        }
        let descriptors = actionDescriptors
        if !descriptors.isEmpty {
            lines.append("approved actions: \(descriptors.map(\.id).prefix(8).joined(separator: ","))")
            for descriptor in descriptors.prefix(8) {
                let approval = descriptor.requiresApproval ? "approval required" : "no approval"
                let mutation = descriptor.mutatesAppState ? "mutates app state" : "read-only"
                lines.append("action \(descriptor.id): \(Self.clippedInline(descriptor.summary, limit: 120)) (\(approval), \(mutation))")
            }
        }
        for line in capabilityLines {
            guard let normalized = Self.normalized(line, limit: 120) else { continue }
            lines.append(normalized)
        }
        return lines
    }

    private var allApprovedActionIDs: Set<String> {
        var ids = Set(approvedActions)
        if let note {
            ids.formUnion(["note.read", "note.update", "note.rewrite-selection", "note.delete.with-approval"])
            if note.selectedText != nil {
                ids.insert("selected-text.rewrite.with-approval")
            }
        }
        if let graph {
            ids.formUnion(graph.approvedActions)
        }
        if let vault {
            ids.formUnion(vault.approvedActions)
        }
        if !additionalContextAttachments.isEmpty {
            ids.insert("app-context.snapshot")
        }
        return ids
    }

    private static let actionCatalog: [ActionDescriptor] = [
        ActionDescriptor(
            id: "app-context.snapshot",
            title: "App Context Snapshot",
            summary: "Read the bounded Epistemos portal, session, vault, note, graph, attachment, and capability context.",
            portalScopes: [.main, .landing, .mini, .note, .graph, .vault],
            requiresApproval: false,
            mutatesAppState: false,
            resourceURI: "epistemos://app/context"
        ),
        ActionDescriptor(
            id: "vault.search",
            title: "Vault Search",
            summary: "Search approved Epistemos vault metadata and note resources through app-owned APIs.",
            portalScopes: [.main, .landing, .mini, .note, .graph, .vault],
            requiresApproval: false,
            mutatesAppState: false,
            resourceURI: "epistemos://vault/search"
        ),
        ActionDescriptor(
            id: "note.read",
            title: "Read Note",
            summary: "Read the active note context, visible excerpt, selected text, tags, backlinks, and note metadata.",
            portalScopes: [.note],
            requiresApproval: false,
            mutatesAppState: false,
            resourceURI: "epistemos://note/read"
        ),
        ActionDescriptor(
            id: "note.create",
            title: "Create Note",
            summary: "Create a new note in the Epistemos vault through the app note service.",
            portalScopes: [.landing, .vault],
            requiresApproval: true,
            mutatesAppState: true,
            resourceURI: "epistemos://note/create"
        ),
        ActionDescriptor(
            id: "note.update",
            title: "Update Note",
            summary: "Update an approved note through the Epistemos note service; never write files directly.",
            portalScopes: [.landing, .note, .vault],
            requiresApproval: true,
            mutatesAppState: true,
            resourceURI: "epistemos://note/update"
        ),
        ActionDescriptor(
            id: "note.rewrite-selection",
            title: "Rewrite Selection",
            summary: "Propose or apply a rewrite for approved selected note text through native note actions.",
            portalScopes: [.note],
            requiresApproval: true,
            mutatesAppState: true,
            resourceURI: "epistemos://note/rewrite-selection"
        ),
        ActionDescriptor(
            id: "selected-text.rewrite.with-approval",
            title: "Rewrite Selected Text",
            summary: "Rewrite selected text only after native Epistemos approval.",
            portalScopes: [.note],
            requiresApproval: true,
            mutatesAppState: true,
            resourceURI: "epistemos://note/selected-text/rewrite"
        ),
        ActionDescriptor(
            id: "note.delete.with-approval",
            title: "Delete Note",
            summary: "Delete an approved note only after native Epistemos approval.",
            portalScopes: [.note, .vault],
            requiresApproval: true,
            mutatesAppState: true,
            resourceURI: "epistemos://note/delete"
        ),
        ActionDescriptor(
            id: "graph.read",
            title: "Read Graph",
            summary: "Read selected graph nodes, edges, route, and neighborhood summary from the graph workspace.",
            portalScopes: [.graph],
            requiresApproval: false,
            mutatesAppState: false,
            resourceURI: "epistemos://graph/read"
        ),
        ActionDescriptor(
            id: "graph.neighborhood",
            title: "Graph Neighborhood",
            summary: "Read a bounded graph neighborhood around the current selection.",
            portalScopes: [.graph],
            requiresApproval: false,
            mutatesAppState: false,
            resourceURI: "epistemos://graph/neighborhood"
        ),
        ActionDescriptor(
            id: "graph.mutate.with-approval",
            title: "Mutate Graph",
            summary: "Request graph mutations only through native approval and graph workspace actions.",
            portalScopes: [.graph],
            requiresApproval: true,
            mutatesAppState: true,
            resourceURI: "epistemos://graph/mutate"
        ),
        ActionDescriptor(
            id: "session.resume",
            title: "Resume Session",
            summary: "Resume the current Epistemos agent session identity without pretending transcript persistence exists.",
            portalScopes: [.main, .mini],
            requiresApproval: false,
            mutatesAppState: false,
            resourceURI: "epistemos://session/resume"
        ),
        ActionDescriptor(
            id: "session.summary",
            title: "Session Summary",
            summary: "Create a bounded summary of the active Epistemos agent session context.",
            portalScopes: [.main, .landing, .mini, .note, .graph, .vault],
            requiresApproval: false,
            mutatesAppState: false,
            resourceURI: "epistemos://session/summary"
        ),
        ActionDescriptor(
            id: "skill.discovery",
            title: "Skill Discovery",
            summary: "Read available Epistemos skills and commands exposed to the agent surface.",
            portalScopes: [.main, .landing, .mini, .note, .graph, .vault],
            requiresApproval: false,
            mutatesAppState: false,
            resourceURI: "epistemos://skills/discovery"
        ),
        ActionDescriptor(
            id: "route.to.agent",
            title: "Route To Agent",
            summary: "Route a Landing request into the shared AgentClone/fusion agent session.",
            portalScopes: [.landing],
            requiresApproval: false,
            mutatesAppState: false,
            resourceURI: "epistemos://route/agent"
        ),
    ]

    private static func normalizedNote(_ note: NoteContext) -> NoteContext {
        NoteContext(
            pageId: normalized(note.pageId, limit: 96) ?? "unknown-note",
            title: normalized(note.title, limit: 120),
            path: normalized(note.path, limit: 260),
            selectedText: normalized(note.selectedText, limit: 1_200),
            visibleExcerpt: normalized(note.visibleExcerpt, limit: 1_200),
            backlinks: normalizedList(note.backlinks, limit: 12, itemLimit: 120),
            tags: normalizedList(note.tags, limit: 12, itemLimit: 64)
        )
    }

    private static func normalizedGraph(_ graph: GraphContext) -> GraphContext {
        GraphContext(
            route: normalized(graph.route, limit: 160),
            selectedNodeIds: normalizedList(graph.selectedNodeIds, limit: 24, itemLimit: 96),
            selectedEdgeIds: normalizedList(graph.selectedEdgeIds, limit: 24, itemLimit: 96),
            neighborhoodSummary: normalized(graph.neighborhoodSummary, limit: 1_200),
            approvedActions: normalizedList(graph.approvedActions, limit: 12, itemLimit: 80)
        )
    }

    private static func normalizedVault(_ vault: VaultContext) -> VaultContext {
        VaultContext(
            rootPath: normalized(vault.rootPath, limit: 260),
            workspacePath: normalized(vault.workspacePath, limit: 260),
            storageSummary: normalized(vault.storageSummary, limit: 320),
            approvedActions: normalizedList(vault.approvedActions, limit: 12, itemLimit: 80)
        )
    }

    private static func normalizedList(_ values: [String], limit: Int, itemLimit: Int) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for value in values {
            guard let item = normalized(value, limit: itemLimit), seen.insert(item).inserted else {
                continue
            }
            result.append(item)
            if result.count >= limit {
                break
            }
        }
        return result
    }

    private static func normalizedAttachments(_ attachments: [ContextAttachment], limit: Int) -> [ContextAttachment] {
        var seen = Set<String>()
        var result: [ContextAttachment] = []
        for attachment in attachments where seen.insert(attachment.id).inserted {
            result.append(attachment)
            if result.count >= limit {
                break
            }
        }
        return result
    }

    private static func normalized(_ value: String?, limit: Int) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard trimmed.count > limit else { return trimmed }
        return String(trimmed.prefix(limit - 3)) + "..."
    }

    private static func clippedPath(_ path: String) -> String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: "/").map(String.init)
        guard parts.count > 2 else {
            return clippedInline(trimmed, limit: 96)
        }
        return clippedInline(".../" + parts.suffix(2).joined(separator: "/"), limit: 96)
    }

    private static func clippedInline(_ value: String, limit: Int) -> String {
        let singleLine = value
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard singleLine.count > limit else { return singleLine }
        return String(singleLine.prefix(limit - 3)) + "..."
    }

    private static func encodedJSONString<Value: Encodable>(_ value: Value) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(value),
              let string = String(data: data, encoding: .utf8)
        else {
            return "{}"
        }
        return string
    }
}
