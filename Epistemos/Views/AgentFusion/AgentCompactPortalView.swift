import AgentClone
import SwiftUI

struct AgentCompactPortalView: View {
    @Environment(AgentChatState.self) private var agentChat
    @Environment(UIState.self) private var ui
    @Environment(VaultSyncService.self) private var vaultSync
    @FocusState private var promptFocused: Bool
    @State private var promptText = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.45)
            transcript
            Divider().opacity(0.45)
            composer
        }
        .background(ui.theme.chatSurface)
        .foregroundStyle(ui.theme.textPrimary)
        .task { @MainActor in
            syncAgentCloneHostContext()
            promptFocused = true
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Epistemos")
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                Text(sessionStatus)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(ui.theme.textSecondary)
            }

            Spacer(minLength: 12)

            Button {
                startCompactSession()
            } label: {
                Image(systemName: "plus")
                    .frame(width: 28, height: 26)
            }
            .buttonStyle(.plain)
            .help("New agent session")

            Button {
                openFullAgent()
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .frame(width: 28, height: 26)
            }
            .buttonStyle(.plain)
            .help("Open in main Agent")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var transcript: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                if agentChat.messages.isEmpty && agentChat.streamingText.isEmpty {
                    emptyState
                    compactRecentSessions
                } else {
                    ForEach(agentChat.messages.suffix(8)) { message in
                        messageRow(message)
                    }
                    if !agentChat.streamingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        streamingRow(agentChat.streamingText)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ask anything")
                .font(.system(size: 18, weight: .semibold))
            Text("Compact portal into the shared agent session.")
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundStyle(ui.theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 28)
    }

    @ViewBuilder
    private var compactRecentSessions: some View {
        if !agentChat.recentPortalSessions.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Recent")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(ui.theme.textSecondary)
                    .textCase(.uppercase)
                ForEach(Array(agentChat.recentPortalSessions.prefix(4))) { summary in
                    Button {
                        activateRecentPortalSession(summary)
                    } label: {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: symbol(for: summary.portal))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(ui.theme.textSecondary)
                                .frame(width: 16)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(summary.title)
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(ui.theme.textPrimary)
                                    .lineLimit(1)
                                Text(recentDetail(summary))
                                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                                    .foregroundStyle(ui.theme.textSecondary)
                                    .lineLimit(2)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 7)
                        .background(ui.theme.card.opacity(0.52), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .help("Activate portal context")
                }
            }
            .padding(.top, 8)
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 8) {
            compactContextBar
            compactActionChips

            HStack(alignment: .bottom, spacing: 8) {
                TextField("Ask anything...", text: $promptText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: .regular, design: .monospaced))
                    .lineLimit(1...5)
                    .focused($promptFocused)
                    .onSubmit(submitCompactPrompt)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 9)
                    .background(ui.theme.card, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(ui.theme.border.opacity(0.75), lineWidth: 0.5)
                    )

                Button(action: submitCompactPrompt) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 13, weight: .bold))
                        .frame(width: 32, height: 32)
                        .background(ui.theme.uiAccent.opacity(canSubmit ? 0.18 : 0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(ui.theme.uiAccent.opacity(canSubmit ? 0.65 : 0.2), lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!canSubmit)
                .help("Send")
            }
        }
        .padding(12)
    }

    private var compactContextBar: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol(for: compactResolvedPortalContext.portal))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(ui.theme.textSecondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(compactContextTitle)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(ui.theme.textPrimary)
                    .lineLimit(1)
                Text(compactContextDetail)
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundStyle(ui.theme.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            Button {
                appendCompactAppContextSnapshotIntent()
            } label: {
                Image(systemName: "doc.badge.gearshape")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 28, height: 24)
            }
            .buttonStyle(.plain)
            .help("Use context")
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(ui.theme.card.opacity(0.62), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(ui.theme.border.opacity(0.55), lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private var compactActionChips: some View {
        if !compactActionDescriptors.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(compactActionDescriptors, id: \.id) { action in
                        Button {
                            appendCompactActionIntent(action)
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: compactActionSystemImage(action))
                                    .font(.system(size: 10, weight: .semibold))
                                Text(action.title)
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .lineLimit(1)
                                if action.requiresApproval {
                                    Image(systemName: "checkmark.shield")
                                        .font(.system(size: 9, weight: .semibold))
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(ui.theme.card.opacity(action.requiresApproval ? 0.68 : 0.52), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .strokeBorder(compactActionBorder(action), lineWidth: 0.5)
                            )
                        }
                        .buttonStyle(.plain)
                        .help(compactActionHelp(action))
                    }
                }
                .padding(.horizontal, 1)
            }
        }
    }

    private func messageRow(_ message: ChatMessage) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(message.role == .user ? "you" : "agent")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(ui.theme.textSecondary)
            Text(message.effectiveText)
                .font(.system(size: 13, weight: .regular, design: message.role == .user ? .monospaced : .default))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .background(rowBackground(for: message), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func streamingRow(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("agent")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(ui.theme.textSecondary)
            Text(text)
                .font(.system(size: 13))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .background(ui.theme.card.opacity(0.72), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func rowBackground(for message: ChatMessage) -> Color {
        message.role == .user
            ? ui.theme.uiAccent.opacity(0.10)
            : ui.theme.card.opacity(0.68)
    }

    private var canSubmit: Bool {
        !promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var sessionStatus: String {
        guard let sessionId = agentChat.activeSessionId else { return "ready" }
        return "session \(String(sessionId.prefix(8)))"
    }

    private var compactResolvedPortalContext: AgentPortalContextSnapshot {
        agentChat.activePortalContext ?? compactPortalContext
    }

    private var compactVisibleSessionId: String? {
        agentChat.activeSessionId ?? compactResolvedPortalContext.sessionId
    }

    private var compactContextTitle: String {
        let portalContext = compactResolvedPortalContext
        var parts = [portalContext.portal.label]
        if let title = portalContext.title, title != portalContext.portal.label {
            parts.append(title)
        }
        return parts.joined(separator: " | ")
    }

    private var compactContextDetail: String {
        let portalContext = compactResolvedPortalContext
        var parts: [String] = []
        if let note = portalContext.note {
            parts.append("note: \(note.title ?? note.pageId)")
        }
        if let graph = portalContext.graph {
            if let route = graph.route {
                parts.append("graph: \(route)")
            } else if !graph.selectedNodeIds.isEmpty {
                parts.append("graph: \(graph.selectedNodeIds.count) nodes")
            } else {
                parts.append("graph: context")
            }
        }
        if !portalContext.additionalContextAttachments.isEmpty {
            parts.append("\(portalContext.additionalContextAttachments.count) attached")
        }
        if let sessionId = compactVisibleSessionId {
            parts.append("session \(String(sessionId.prefix(8)))")
        }
        if parts.isEmpty {
            parts.append("shared session context")
        }
        return parts.map { clippedInline($0, limit: 42) }.prefix(3).joined(separator: " | ")
    }

    private var compactActionDescriptors: [AgentPortalContextSnapshot.ActionDescriptor] {
        Array(compactResolvedPortalContext.actionDescriptors.prefix(5))
    }

    private var compactApprovedActionChips: [String] {
        compactActionDescriptors.map(\.id)
    }

    private var compactAppContextSnapshotText: String {
        let portalContext = compactResolvedPortalContext
        var lines: [String] = [
            "portal: \(portalContext.portal.label)",
            "session: \(clippedSession(compactVisibleSessionId))",
            "vault: \(clippedPath(portalContext.vault?.rootPath ?? vaultSync.vaultURL?.path))",
            "workspace: \(clippedPath(portalContext.vault?.workspacePath ?? FileManager.default.homeDirectoryForCurrentUser.path))",
        ]

        if let title = portalContext.title {
            lines.append("title: \(clippedInline(title, limit: 80))")
        }
        if let promptPreview = portalContext.promptPreview {
            lines.append("prompt: \(clippedInline(promptPreview, limit: 100))")
        }
        if let note = portalContext.note {
            lines.append("note: \(clippedInline(note.title ?? note.pageId, limit: 80))")
            if let selectedText = note.selectedText {
                lines.append("selection: \(clippedInline(selectedText, limit: 120))")
            } else if let visibleExcerpt = note.visibleExcerpt {
                lines.append("excerpt: \(clippedInline(visibleExcerpt, limit: 120))")
            }
            if !note.tags.isEmpty {
                lines.append("tags: \(note.tags.prefix(4).joined(separator: ","))")
            }
        }
        if let graph = portalContext.graph {
            if let route = graph.route {
                lines.append("graph: \(clippedInline(route, limit: 80))")
            }
            if !graph.selectedNodeIds.isEmpty {
                lines.append("graph nodes: \(graph.selectedNodeIds.prefix(6).joined(separator: ","))")
            }
            if !graph.selectedEdgeIds.isEmpty {
                lines.append("graph edges: \(graph.selectedEdgeIds.prefix(6).joined(separator: ","))")
            }
            if let neighborhood = graph.neighborhoodSummary {
                lines.append("neighborhood: \(clippedInline(neighborhood, limit: 120))")
            }
        }
        if !portalContext.additionalContextAttachments.isEmpty {
            lines.append("attached: \(portalContext.additionalContextAttachments.map(\.title).prefix(6).joined(separator: ","))")
        }
        if !compactApprovedActionChips.isEmpty {
            lines.append("approved actions: \(compactApprovedActionChips.joined(separator: ","))")
        }

        return lines.prefix(14).map { "- \($0)" }.joined(separator: "\n")
    }

    private func recentDetail(_ summary: AgentPortalSessionSummary) -> String {
        var parts = [summary.portal.label]
        if let promptPreview = summary.promptPreview {
            parts.append(promptPreview)
        }
        if summary.messageCount > 0 {
            parts.append("\(summary.messageCount) messages")
        }
        return parts.joined(separator: " | ")
    }

    private func symbol(for portal: AgentPortalContextSnapshot.Portal) -> String {
        switch portal {
        case .main:
            "sparkles"
        case .landing:
            "house"
        case .mini:
            "rectangle.on.rectangle"
        case .note:
            "note.text"
        case .graph:
            "point.3.connected.trianglepath.dotted"
        case .vault:
            "books.vertical"
        }
    }

    private var compactPortalContext: AgentPortalContextSnapshot {
        AgentPortalContextSnapshot.mini(
            vaultRootPath: vaultSync.vaultURL?.path,
            workspacePath: FileManager.default.homeDirectoryForCurrentUser.path,
            sessionId: agentChat.activeSessionId,
            promptPreview: promptText,
            sourceTitle: "Compact agent"
        )
    }

    private var compactSubmissionPortalContext: AgentPortalContextSnapshot {
        var portalContext = compactResolvedPortalContext
        portalContext.promptPreview = promptText
        if let sessionId = agentChat.activeSessionId {
            portalContext = portalContext.withSessionId(sessionId)
        }
        return portalContext
    }

    private func startCompactSession() {
        let portalContext = compactPortalContext
        agentChat.startNewSession(portalContext: portalContext)
        syncAgentCloneHostContext(portalContext: agentChat.activePortalContext ?? portalContext)
        promptFocused = true
    }

    private func submitCompactPrompt() {
        let trimmed = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let portalContext = compactSubmissionPortalContext
        if agentChat.activeSessionId == nil {
            agentChat.startNewSession(portalContext: portalContext)
        }
        agentChat.submitAgentQuery(trimmed, portalContext: portalContext)
        syncAgentCloneHostContext(portalContext: agentChat.activePortalContext ?? portalContext)
        AgentCloneBridge.submitPrompt(portalContext.agentClonePromptEnvelope(userPrompt: trimmed))
        promptText = ""
        promptFocused = true
    }

    private func openFullAgent() {
        let portalContext = agentChat.activePortalContext ?? compactPortalContext
        AgentPortalRouteRequest.post(portalContext)
    }

    private func activateRecentPortalSession(_ summary: AgentPortalSessionSummary) {
        agentChat.activatePortalSession(summary)
        syncAgentCloneHostContext(portalContext: agentChat.activePortalContext ?? summary.portalContext)
        promptText = ""
        promptFocused = true
    }

    private func appendCompactAppContextSnapshotIntent() {
        let prompt = "Use this Epistemos compact portal context:\n\(compactAppContextSnapshotText)"
        let trimmed = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        promptText = trimmed.isEmpty ? prompt : "\(trimmed)\n\n\(prompt)"
        promptFocused = true
    }

    private func appendCompactActionIntent(_ action: AgentPortalContextSnapshot.ActionDescriptor) {
        let approval = action.requiresApproval ? " Request native approval before changing app state." : ""
        let prompt = "Use \(action.title) (\(action.id)) for this portal context.\(approval)"
        let trimmed = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        promptText = trimmed.isEmpty ? prompt : "\(trimmed) \(prompt)"
        promptFocused = true
    }

    private func compactActionHelp(_ action: AgentPortalContextSnapshot.ActionDescriptor) -> String {
        let approval = action.requiresApproval ? "approval required" : "no approval"
        let mutation = action.mutatesAppState ? "mutates app state" : "read-only"
        return "\(action.id): \(approval), \(mutation). \(action.summary)"
    }

    private func compactActionBorder(_ action: AgentPortalContextSnapshot.ActionDescriptor) -> Color {
        action.requiresApproval
            ? ui.theme.uiAccent.opacity(0.52)
            : ui.theme.border.opacity(0.45)
    }

    private func compactActionSystemImage(_ action: AgentPortalContextSnapshot.ActionDescriptor) -> String {
        let actionId = action.id
        if actionId.contains("note") {
            return "note.text"
        }
        if actionId.contains("graph") {
            return "point.3.connected.trianglepath.dotted"
        }
        if actionId.contains("vault") {
            return "books.vertical"
        }
        if actionId.contains("skill") {
            return "wand.and.stars"
        }
        if actionId.contains("session") {
            return "clock.arrow.circlepath"
        }
        if actionId.contains("route") {
            return "arrow.turn.up.right"
        }
        return "sparkles"
    }

    private func clippedSession(_ sessionId: String?) -> String {
        guard let sessionId else { return "none" }
        return String(sessionId.prefix(8))
    }

    private func clippedPath(_ path: String?) -> String {
        guard let path, !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "none"
        }
        return clippedInline(path, limit: 96)
    }

    private func clippedInline(_ value: String, limit: Int) -> String {
        let singleLine = value
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard singleLine.count > limit else { return singleLine }
        return String(singleLine.prefix(limit - 3)) + "..."
    }

    private func syncAgentCloneHostContext(portalContext: AgentPortalContextSnapshot? = nil) {
        let resolvedPortal = portalContext ?? agentChat.activePortalContext ?? compactPortalContext
        AgentCloneBridge.updateHostContext(AgentCloneHostContext(
            appName: "Epistemos",
            workspaceRootPath: FileManager.default.homeDirectoryForCurrentUser.path,
            vaultRootPath: vaultSync.vaultURL?.path,
            appSupportRootPath: AgentCloneAppContextSnapshot.defaultAppSupportPath(appName: "Epistemos"),
            mode: "Act",
            presentation: resolvedPortal.bridgePresentation
        ))
    }
}
