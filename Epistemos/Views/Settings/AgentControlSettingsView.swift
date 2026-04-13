import SwiftUI

struct AgentControlDetailView: View {
    @Environment(MCPBridge.self) private var mcpBridge
    @Environment(VaultSyncService.self) private var vaultSync

    @State private var recentExecutions: [MCPExecutionEntry] = []
    @State private var sessionResults: [SessionBrowser.SessionInfo] = []
    @State private var sessionQuery: String = ""
    @State private var approvalStore = AgentApprovalPolicyStore()
    @State private var allowlistDraft: String = ""
    @State private var blocklistDraft: String = ""

    private let browser = SessionBrowser.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                headerCard
                toolInventoryCard
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
        }
        .task(id: vaultSync.vaultURL?.path) {
            refreshSessions()
            refreshApprovalPolicy()
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

    private func sessionPreview(for session: SessionBrowser.SessionInfo) -> String? {
        let sections = browser.summarySections(for: session)
        if let firstSection = sections.first {
            return "\(firstSection.title): \(firstSection.body.replacingOccurrences(of: "\n", with: " "))"
        }
        return browser.loadSummary(for: session)?
            .components(separatedBy: .newlines)
            .first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !$0.hasPrefix("#") })
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
