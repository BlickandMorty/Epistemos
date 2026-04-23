import SwiftUI

private struct ActiveGrantSettingsRow: Identifiable {
    let id: String
    let title: String
    let detail: String
    let systemImage: String
    let isRevocable: Bool
}

struct AgentControlDetailView: View {
    @Environment(MCPBridge.self) private var mcpBridge
    @Environment(VaultSyncService.self) private var vaultSync
    @Environment(ChatState.self) private var chat

    @State private var recentExecutions: [MCPExecutionEntry] = []
    @State private var sessionResults: [SessionBrowser.SessionInfo] = []
    @State private var sessionQuery: String = ""
    @State private var approvalStore = AgentApprovalPolicyStore()
    @State private var customTools: [CustomToolRecord] = []
    @State private var customToolDraftJSON: String = CustomToolRecord.exampleJSON
    @State private var customToolStatusMessage: String?
    @State private var customToolStatusIsError = false
    @State private var isMutatingCustomTools = false
    @State private var allowlistDraft: String = ""
    @State private var blocklistDraft: String = ""
    // Phase R.5 — Rust-backed permission grants (I-009/I-010). Populated
    // from `permissionStoreListActive()` in `agent_core`. Surfaced in the
    // Active Grants section alongside the derived, session-local rows so
    // the user can see + revoke durable grants stored in Rust. Fresh
    // launch is empty until the first user-grant phrasing lands.
    @State private var rustBackedGrants: [PermissionGrantSummary] = []
    @State private var isRevokingGrantId: String?

    private let browser = SessionBrowser.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                headerCard
                toolInventoryCard
                customToolsCard
                approvalPolicyCard
                recentExecutionsCard
                sessionsCard
            }
            .padding(24)
            .frame(maxWidth: 920, alignment: .topLeading)
        }
        .task {
            refreshExecutions()
            refreshSessions()
            await refreshRustBackedGrants()
        }
        .task(id: vaultSync.vaultURL?.path) {
            refreshSessions()
            refreshApprovalPolicy()
            await refreshCustomTools()
        }
        .task(id: sessionQuery) {
            refreshSessions()
        }
    }

    private var headerCard: some View {
        SettingsSurfaceCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Agent Control")
                    .font(.title2.weight(.semibold))

                Text("This is the operator-facing view of Epistemos: registered MCP tools, recent tool activity, and cross-session recall. It makes the runtime feel closer to an always-on employee console instead of a single chat box.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var approvalPolicyCard: some View {
        SettingsSurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Approval Policy")
                        .font(.headline)
                    Spacer()
                    Button("Refresh") {
                        refreshApprovalPolicy()
                    }
                }

                activeGrantsSection

                if vaultSync.vaultURL == nil {
                    Text("Attach a vault to inspect or edit the persistent approval policy.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    HStack(spacing: 12) {
                        ChannelStatusPill(title: "\(approvalStore.snapshot.allowlist.count) allow", tint: .green)
                        ChannelStatusPill(title: "\(approvalStore.snapshot.blocklist.count) block", tint: .orange)
                        ChannelStatusPill(title: "\(approvalStore.history.count) recent decisions", tint: .blue)
                    }

                    Text("Permanent allow/block patterns are saved in `.epistemos/approval_lists.json`. Recent decisions are pulled from session trace events so the approval system is explainable instead of opaque.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Allowlist")
                                .font(.subheadline.weight(.semibold))
                            HStack(spacing: 8) {
                                TextField("Always allow pattern", text: $allowlistDraft)
                                    .textFieldStyle(.roundedBorder)
                                Button("Add") {
                                    mutateApprovalPolicy(kind: .allowlist, pattern: allowlistDraft)
                                }
                                .disabled(allowlistDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                            approvalPatternList(
                                approvalStore.snapshot.allowlist,
                                tint: .green,
                                kind: .allowlist
                            )
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Blocklist")
                                .font(.subheadline.weight(.semibold))
                            HStack(spacing: 8) {
                                TextField("Always block pattern", text: $blocklistDraft)
                                    .textFieldStyle(.roundedBorder)
                                Button("Add") {
                                    mutateApprovalPolicy(kind: .blocklist, pattern: blocklistDraft)
                                }
                                .disabled(blocklistDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                            approvalPatternList(
                                approvalStore.snapshot.blocklist,
                                tint: .orange,
                                kind: .blocklist
                            )
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    }

                    Divider()

                    Text("Recent Decisions")
                        .font(.subheadline.weight(.semibold))

                    if approvalStore.history.isEmpty {
                        Text("No approval decisions captured yet.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(approvalStore.history) { entry in
                            VStack(alignment: .leading, spacing: 5) {
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(entry.toolName)
                                            .font(.subheadline.weight(.semibold))
                                        Text(entry.sessionFolderName)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    ChannelStatusPill(
                                        title: entry.outcome.rawValue.capitalized,
                                        tint: entry.outcome == .approved ? .green : .orange
                                    )
                                    if let timestamp = entry.timestamp {
                                        ChannelStatusPill(
                                            title: timestamp.formatted(date: .omitted, time: .shortened),
                                            tint: .secondary
                                        )
                                    }
                                }

                                Text(entry.reason)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)

                                if let inputSummary = entry.inputSummary, !inputSummary.isEmpty {
                                    Text(inputSummary)
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.tertiary)
                                        .lineLimit(2)
                                }
                            }

                            if entry.id != approvalStore.history.last?.id {
                                Divider()
                            }
                        }
                    }
                }

                if let lastError = approvalStore.lastError, !lastError.isEmpty {
                    Label(lastError, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private var activeGrantsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Active Grants")
                .font(.subheadline.weight(.semibold))

            if activeGrantRows.isEmpty && rustBackedGrants.isEmpty {
                Text("No active grants in this chat right now.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(activeGrantRows) { row in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: row.systemImage)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.blue)
                                .frame(width: 16, alignment: .center)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.title)
                                    .font(.subheadline.weight(.semibold))
                                Text(row.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if row.isRevocable {
                                Button("Revoke") {
                                    revokeActiveGrant(row.id)
                                }
                                .buttonStyle(.borderless)
                                .font(.caption.weight(.semibold))
                            } else {
                                ChannelStatusPill(title: "Automatic", tint: .secondary)
                            }
                        }

                        if row.id != activeGrantRows.last?.id {
                            Divider()
                        }
                    }
                }
            }

            // Phase R.5 — Rust-backed persisted grants (I-009/I-010).
            // These are grants the user explicitly stated in chat ("you
            // have my permission") that were parsed + stored in the Rust
            // PermissionService, as distinct from the transient
            // attachment-derived rows above.
            if !rustBackedGrants.isEmpty {
                Divider()
                Text("Stored session grants")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                ForEach(rustBackedGrants, id: \.grantId) { grant in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "lock.shield")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.purple)
                            .frame(width: 16, alignment: .center)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(rustGrantTitle(for: grant))
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Text(rustGrantDetail(for: grant))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button(isRevokingGrantId == grant.grantId ? "Revoking…" : "Revoke") {
                            revokeRustBackedGrant(grant.grantId)
                        }
                        .buttonStyle(.borderless)
                        .font(.caption.weight(.semibold))
                        .disabled(isRevokingGrantId == grant.grantId)
                    }

                    if grant.grantId != rustBackedGrants.last?.grantId {
                        Divider()
                    }
                }
            }

            Divider()
        }
    }

    // MARK: - Phase R.5 — Rust permission-store helpers

    /// Pull the latest active grants from the Rust PermissionService and
    /// publish them to the view. Safe to call from any `.task { ... }`
    /// context; the Rust side drives its own tokio runtime.
    private func refreshRustBackedGrants() async {
        let fetched = await permissionStoreListActive()
        // Use MainActor.run to update @State on the main actor; UniFFI
        // delivers off-main by default.
        await MainActor.run {
            self.rustBackedGrants = fetched
        }
    }

    /// Revoke a Rust-stored grant by ID. Optimistically toggles a busy
    /// flag so the button disables during the round-trip; on success,
    /// re-fetches the authoritative list.
    private func revokeRustBackedGrant(_ grantId: String) {
        isRevokingGrantId = grantId
        Task {
            _ = await permissionStoreRevoke(grantId: grantId)
            await refreshRustBackedGrants()
            await MainActor.run {
                if self.isRevokingGrantId == grantId {
                    self.isRevokingGrantId = nil
                }
            }
        }
    }

    private func rustGrantTitle(for grant: PermissionGrantSummary) -> String {
        // Selector format is "resource:<uri>" / "prefix:<pfx>" /
        // "vault:<id>" / "kind:<Kind>". Use the user-friendly tail.
        if let uri = grant.selector.split(separator: ":", maxSplits: 1).last {
            return String(uri)
        }
        return grant.selector
    }

    private func rustGrantDetail(for grant: PermissionGrantSummary) -> String {
        let caps = grant.capabilities.joined(separator: " + ")
        return "\(caps) · \(grant.scope) · granted by \(grant.grantedBy)"
    }

    private var customToolsCard: some View {
        SettingsSurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Custom Tools")
                        .font(.headline)
                    Spacer()
                    if isMutatingCustomTools {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Button("Refresh") {
                        Task { await refreshCustomTools() }
                    }
                }

                if let vaultPath = vaultSync.vaultURL?.path {
                    Text("Paste a tool spec JSON and save it. Saved tools become real runtime tools the model can call, with their own schema, tier, risk level, and shell-backed execution template.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Tool Spec JSON")
                        .font(.subheadline.weight(.semibold))

                    TextEditor(text: $customToolDraftJSON)
                        .font(.caption.monospaced())
                        .frame(minHeight: 240)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(.thinMaterial)
                        )

                    HStack(spacing: 10) {
                        Button("Save Tool") {
                            Task { await saveCustomTool(vaultPath: vaultPath) }
                        }
                        .disabled(customToolDraftJSON.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        Button("Reset Example") {
                            customToolDraftJSON = CustomToolRecord.exampleJSON
                        }

                        Text("Use `{{input_name}}` placeholders inside `command_template` and optional `workdir`.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    if let customToolStatusMessage {
                        Label(
                            customToolStatusMessage,
                            systemImage: customToolStatusIsError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill"
                        )
                        .font(.caption)
                        .foregroundStyle(customToolStatusIsError ? .orange : .green)
                    }

                    Divider()

                    if customTools.isEmpty {
                        Text("No custom tools saved yet.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(customTools) { tool in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(tool.name)
                                            .font(.subheadline.weight(.semibold))
                                        Text(tool.description)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    Spacer()
                                    ChannelStatusPill(title: tool.tierLabel, tint: .blue)
                                    ChannelStatusPill(title: tool.riskLabel, tint: tool.riskTint)
                                }

                                if let guidance = tool.guidance, !guidance.isEmpty {
                                    Text(guidance)
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }

                                HStack(spacing: 12) {
                                    Button("Load") {
                                        customToolDraftJSON = tool.jsonText
                                    }
                                    Button("Delete") {
                                        Task { await deleteCustomTool(named: tool.name, vaultPath: vaultPath) }
                                    }
                                    .foregroundStyle(.orange)
                                    Text(tool.commandTemplate)
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.tertiary)
                                        .lineLimit(1)
                                }
                            }

                            if tool.id != customTools.last?.id {
                                Divider()
                            }
                        }
                    }
                } else {
                    Text("Attach a vault to create and persist custom tools.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var toolInventoryCard: some View {
        SettingsSurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("MCP Tool Plane")
                    .font(.headline)

                HStack(spacing: 12) {
                    ChannelStatusPill(title: "\(mcpBridge.toolCount) tools", tint: .blue)
                    ChannelStatusPill(title: "\(mcpBridge.executionCount) executions", tint: .green)
                    ChannelStatusPill(
                        title: "\(OmegaToolRegistry.all.filter(\.requiresConfirmation).count) approvals",
                        tint: .orange
                    )
                }

                ForEach(toolGroups) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(group.title)
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("\(group.tools.count)")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                        }

                        Text(group.tools.map(\.name).joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if group.id != toolGroups.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    private var recentExecutionsCard: some View {
        SettingsSurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Recent Tool Activity")
                        .font(.headline)
                    Spacer()
                    Button("Refresh") {
                        refreshExecutions()
                    }
                }

                if recentExecutions.isEmpty {
                    Text("No tool executions logged yet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(recentExecutions) { execution in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(execution.toolName)
                                        .font(.subheadline.weight(.semibold))
                                    Text(execution.timestampLabel)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                ChannelStatusPill(
                                    title: execution.success ? "Success" : "Failed",
                                    tint: execution.success ? .green : .orange
                                )
                                ChannelStatusPill(
                                    title: "\(execution.durationMs) ms",
                                    tint: .secondary
                                )
                            }

                            if let argumentsPreview = execution.argumentsPreview {
                                Text(argumentsPreview)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }

                        if execution.id != recentExecutions.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private var sessionsCard: some View {
        SettingsSurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Session Index")
                    .font(.headline)

                if vaultSync.vaultURL == nil {
                    Text("Attach a vault to browse indexed sessions.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    TextField("Search sessions by model, provider, summary, or transcript text", text: $sessionQuery)
                        .textFieldStyle(.roundedBorder)

                    if sessionResults.isEmpty {
                        Text("No sessions matched this search.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(sessionResults) { session in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(session.model)
                                            .font(.subheadline.weight(.semibold))
                                        Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if let lineage = browser.lineageSummary(for: session) {
                                        ChannelStatusPill(title: lineage, tint: .blue)
                                    }
                                }

                                if let preview = sessionPreview(for: session) {
                                    Text(preview)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(3)
                                }
                            }

                            if session.id != sessionResults.last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
    }

    private var toolGroups: [ToolInventoryGroup] {
        let grouped = Dictionary(grouping: OmegaToolRegistry.all, by: \.agent)
        return grouped
            .map { ToolInventoryGroup(title: $0.key.capitalized, tools: $0.value.sorted { $0.name < $1.name }) }
            .sorted { $0.title < $1.title }
    }

    private func refreshExecutions() {
        recentExecutions = MCPExecutionEntry.parse(from: mcpBridge.recentExecutionsJson(limit: 12))
    }

    private func refreshCustomTools() async {
        guard let vaultPath = vaultSync.vaultURL?.path else {
            customTools = []
            customToolStatusMessage = nil
            customToolStatusIsError = false
            return
        }

        isMutatingCustomTools = true
        defer { isMutatingCustomTools = false }

        do {
            let response = try await callCustomToolManager(
                payload: ["action": "list"],
                vaultPath: vaultPath
            )
            customTools = CustomToolRecord.parseList(from: response)
        } catch {
            customToolStatusMessage = error.localizedDescription
            customToolStatusIsError = true
        }
    }

    private func refreshSessions() {
        guard let vaultPath = vaultSync.vaultURL?.path else {
            sessionResults = []
            return
        }
        browser.refresh(vaultPath: vaultPath)
        sessionResults = browser.searchSessions(matching: sessionQuery, limit: 10)
    }

    private func refreshApprovalPolicy() {
        guard let vaultPath = vaultSync.vaultURL?.path else {
            approvalStore.snapshot = .empty
            approvalStore.history = []
            approvalStore.lastError = nil
            return
        }
        approvalStore.refresh(vaultPath: vaultPath)
    }

    @ViewBuilder
    private func approvalPatternList(
        _ patterns: [ApprovalPolicyPattern],
        tint: Color,
        kind: ApprovalPolicyListKind
    ) -> some View {
        if patterns.isEmpty {
            Text("No patterns yet.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            ForEach(patterns) { pattern in
                HStack {
                    Text(pattern.pattern)
                        .font(.caption.monospaced())
                    Spacer()
                    Button {
                        removeApprovalPattern(pattern.pattern, from: kind)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(tint)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func mutateApprovalPolicy(kind: ApprovalPolicyListKind, pattern: String) {
        guard let vaultPath = vaultSync.vaultURL?.path else {
            return
        }

        do {
            try approvalStore.add(pattern: pattern, to: kind, vaultPath: vaultPath)
            switch kind {
            case .allowlist:
                allowlistDraft = ""
            case .blocklist:
                blocklistDraft = ""
            }
        } catch {
            approvalStore.lastError = error.localizedDescription
        }
    }

    private func removeApprovalPattern(_ pattern: String, from kind: ApprovalPolicyListKind) {
        guard let vaultPath = vaultSync.vaultURL?.path else {
            return
        }

        do {
            try approvalStore.remove(pattern: pattern, from: kind, vaultPath: vaultPath)
        } catch {
            approvalStore.lastError = error.localizedDescription
        }
    }

    private var activeGrantRows: [ActiveGrantSettingsRow] {
        var rows: [ActiveGrantSettingsRow] = []

        if let vaultURL = vaultSync.vaultURL {
            rows.append(
                ActiveGrantSettingsRow(
                    id: "vault:\(vaultURL.path)",
                    title: vaultURL.lastPathComponent,
                    detail: "Read + Search active vault",
                    systemImage: "books.vertical",
                    isRevocable: false
                )
            )
        }

        rows.append(
            contentsOf: chat.pendingContextAttachments.map { attachment in
                ActiveGrantSettingsRow(
                    id: "context:\(attachment.id)",
                    title: attachment.title,
                    detail: grantDetail(for: attachment),
                    systemImage: attachment.systemImageName,
                    isRevocable: true
                )
            }
        )

        rows.append(
            contentsOf: chat.pendingAttachments.map { attachment in
                ActiveGrantSettingsRow(
                    id: "file:\(attachment.id)",
                    title: attachment.name,
                    detail: "Read attached file",
                    systemImage: fileAttachmentIcon(for: attachment.type),
                    isRevocable: true
                )
            }
        )

        rows.append(
            ActiveGrantSettingsRow(
                id: "shell-approval",
                title: "Shell / external tools",
                detail: "Ask first for destructive or external work",
                systemImage: "terminal",
                isRevocable: false
            )
        )

        return rows
    }

    private func revokeActiveGrant(_ id: String) {
        if id.hasPrefix("context:"), let contextID = id.split(separator: ":", maxSplits: 1).last {
            chat.removeContextAttachment(String(contextID))
            return
        }
        if id.hasPrefix("file:"), let fileID = id.split(separator: ":", maxSplits: 1).last {
            chat.removeAttachment(String(fileID))
        }
    }

    private func grantDetail(for attachment: ContextAttachment) -> String {
        switch attachment.kind {
        case .note:
            return "Read + Edit attached note"
        case .chat:
            return "Read attached chat context"
        case .allNotes:
            return "Read + Search attached vault context"
        case .folder:
            return "Read + Edit attached folder notes"
        }
    }

    private func fileAttachmentIcon(for type: AttachmentType) -> String {
        switch type {
        case .image:
            return "photo"
        case .pdf:
            return "doc.richtext"
        case .csv:
            return "tablecells"
        case .text:
            return "doc.text"
        case .other:
            return "paperclip"
        }
    }

    private func sessionPreview(for session: SessionBrowser.SessionInfo) -> String? {
        let sections = browser.summarySections(for: session)
        if let firstSection = sections.first {
            return "\(firstSection.title): \(firstSection.body.replacingOccurrences(of: "\n", with: " "))"
        }
        return browser.loadSummary(for: session)?
            .components(separatedBy: .newlines)
            .first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !$0.hasPrefix("#") })
    }

    private func saveCustomTool(vaultPath: String) async {
        isMutatingCustomTools = true
        defer { isMutatingCustomTools = false }

        do {
            let spec = try CustomToolRecord.parseDraftObject(from: customToolDraftJSON)
            let name = try CustomToolRecord.toolName(from: spec)
            let action = customTools.contains(where: { $0.name == name }) ? "edit" : "create"
            let response = try await callCustomToolManager(
                payload: [
                    "action": action,
                    "spec": spec,
                ],
                vaultPath: vaultPath
            )
            customToolStatusMessage = CustomToolRecord.statusMessage(from: response, fallback: "\(action == "edit" ? "Updated" : "Created") \(name).")
            customToolStatusIsError = false
            await refreshCustomTools()
        } catch {
            customToolStatusMessage = error.localizedDescription
            customToolStatusIsError = true
        }
    }

    private func deleteCustomTool(named name: String, vaultPath: String) async {
        isMutatingCustomTools = true
        defer { isMutatingCustomTools = false }

        do {
            let response = try await callCustomToolManager(
                payload: [
                    "action": "delete",
                    "name": name,
                ],
                vaultPath: vaultPath
            )
            customToolStatusMessage = CustomToolRecord.statusMessage(from: response, fallback: "Deleted \(name).")
            customToolStatusIsError = false
            await refreshCustomTools()
        } catch {
            customToolStatusMessage = error.localizedDescription
            customToolStatusIsError = true
        }
    }

    private func callCustomToolManager(
        payload: [String: Any],
        vaultPath: String
    ) async throws -> String {
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        let inputJSON = String(data: data, encoding: .utf8) ?? "{}"
        #if canImport(agent_coreFFI)
        let result = try await executeToolCall(
            vaultPath: vaultPath,
            tier: "agent",
            toolName: "tool_manage",
            inputJson: inputJSON
        )
        if let error = result.error, !error.isEmpty {
            throw CustomToolSettingsError.toolError(error)
        }
        if !result.success {
            throw CustomToolSettingsError.toolError("Custom tool manager failed.")
        }
        return result.outputJson
        #else
        throw CustomToolSettingsError.bindingsUnavailable
        #endif
    }
}

private struct ToolInventoryGroup: Identifiable {
    let title: String
    let tools: [OmegaToolDefinition]

    var id: String { title }
}

private struct MCPExecutionEntry: Identifiable {
    let id: String
    let toolName: String
    let timestamp: Date?
    let durationMs: Int
    let success: Bool
    let argumentsPreview: String?

    var timestampLabel: String {
        if let timestamp {
            timestamp.formatted(date: .abbreviated, time: .shortened)
        } else {
            "Unknown time"
        }
    }

    static func parse(from jsonString: String) -> [MCPExecutionEntry] {
        guard let data = jsonString.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }

        let formatter = ISO8601DateFormatter()
        return array.compactMap { row in
            guard let id = row["id"] as? String,
                  let toolName = row["tool_name"] as? String else {
                return nil
            }
            let durationMs = (row["duration_ms"] as? NSNumber)?.intValue
                ?? (row["duration_ms"] as? Int)
                ?? 0
            let success = row["success"] as? Bool ?? false
            let timestamp = (row["timestamp"] as? String).flatMap(formatter.date)
            let argumentsPreview: String?
            if let arguments = row["arguments_json"] as? String {
                argumentsPreview = arguments
            } else if let arguments = row["arguments"] {
                argumentsPreview = String(describing: arguments)
            } else {
                argumentsPreview = nil
            }
            return MCPExecutionEntry(
                id: id,
                toolName: toolName,
                timestamp: timestamp,
                durationMs: durationMs,
                success: success,
                argumentsPreview: argumentsPreview
            )
        }
    }
}

private struct CustomToolRecord: Identifiable {
    let name: String
    let description: String
    let guidance: String?
    let tier: String
    let riskLevel: String
    let commandTemplate: String
    let jsonText: String

    static let exampleJSON = """
    {
      "name": "echo-name",
      "description": "Echo the provided name through the shell-backed runtime.",
      "guidance": "Use this for simple command wrappers instead of falling back to raw terminal calls.",
      "input_schema": {
        "type": "object",
        "properties": {
          "name": {
            "type": "string",
            "description": "Name to print."
          }
        },
        "required": [
          "name"
        ]
      },
      "command_template": "printf %s {{name}}",
      "timeout_secs": 30,
      "risk_level": "read_only",
      "tier": "chat_lite"
    }
    """

    var id: String { name }

    var tierLabel: String {
        tier.replacingOccurrences(of: "_", with: " ").uppercased()
    }

    var riskLabel: String {
        riskLevel.replacingOccurrences(of: "_", with: " ").capitalized
    }

    var riskTint: Color {
        switch riskLevel {
        case "destructive":
            .orange
        case "read_only":
            .green
        default:
            .blue
        }
    }

    static func parseList(from jsonString: String) -> [CustomToolRecord] {
        guard let data = jsonString.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rows = root["tools"] as? [[String: Any]] else {
            return []
        }

        return rows.compactMap { row in
            guard let name = row["name"] as? String,
                  let description = row["description"] as? String,
                  let commandTemplate = row["command_template"] as? String else {
                return nil
            }
            let prettyData = try? JSONSerialization.data(withJSONObject: row, options: [.prettyPrinted, .sortedKeys])
            let jsonText = prettyData.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
            return CustomToolRecord(
                name: name,
                description: description,
                guidance: row["guidance"] as? String,
                tier: row["tier"] as? String ?? "agent",
                riskLevel: row["risk_level"] as? String ?? "modification",
                commandTemplate: commandTemplate,
                jsonText: jsonText
            )
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    static func parseDraftObject(from jsonString: String) throws -> [String: Any] {
        guard let data = jsonString.data(using: .utf8),
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CustomToolSettingsError.invalidDraft("Tool JSON must decode to a top-level object.")
        }
        return object
    }

    static func toolName(from object: [String: Any]) throws -> String {
        guard let name = object["name"] as? String else {
            throw CustomToolSettingsError.invalidDraft("Tool JSON must include a string 'name'.")
        }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw CustomToolSettingsError.invalidDraft("Tool name cannot be empty.")
        }
        return trimmed
    }

    static func statusMessage(from responseJSON: String, fallback: String) -> String {
        guard let data = responseJSON.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return fallback
        }
        if let error = root["error"] as? String, !error.isEmpty {
            return error
        }
        return fallback
    }
}

private enum CustomToolSettingsError: LocalizedError {
    case bindingsUnavailable
    case invalidDraft(String)
    case toolError(String)

    var errorDescription: String? {
        switch self {
        case .bindingsUnavailable:
            "agent_core bindings unavailable"
        case .invalidDraft(let message):
            message
        case .toolError(let message):
            message
        }
    }
}
