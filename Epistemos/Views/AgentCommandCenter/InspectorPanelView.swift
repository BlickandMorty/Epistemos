import SwiftUI

// MARK: - Inspector Panel View
//
// Right-side inspector panel (280pt fixed width). Five tabs:
// Context, Capabilities, Plan, Execution, Hierarchy.
//
// Phase 5 contract: every field rendered here reads from
// `accState.diagnostics` — which is populated by the
// CommandCenterRequestCompiler (compile-time) and the Rust streaming delegate
// (runtime). No inspector field derives truth from local AgentChatState or
// SwiftUI state. If a value is shown, its source is either the compiled
// request or a streaming runtime event.

struct InspectorPanelView: View {
    @Environment(AgentCommandCenterState.self) private var accState
    @Environment(AgentChatState.self) private var agentChat
    @Environment(UIState.self) private var ui
    @AppStorage("epistemos.agent.planDocumentPresentationMode")
    private var planDocumentPresentationModeRaw = MarkdownDocumentPresentationMode.rendered.rawValue

    private var theme: EpistemosTheme { ui.theme }

    private var diagnostics: CommandCenterExecutionDiagnostics {
        accState.diagnostics
    }

    private var activeTab: ACCInspectorTab {
        if case .expanded(let tab) = accState.inspectorState { return tab }
        return .capabilities
    }

    private var planDocumentPresentationMode: MarkdownDocumentPresentationMode {
        get { MarkdownDocumentPresentationMode(rawValue: planDocumentPresentationModeRaw) ?? .rendered }
        nonmutating set { planDocumentPresentationModeRaw = newValue.rawValue }
    }

    private var planDocumentPresentationModeBinding: Binding<MarkdownDocumentPresentationMode> {
        Binding(
            get: { planDocumentPresentationMode },
            set: { planDocumentPresentationMode = $0 }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            tabBar
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 8)

            Divider().opacity(0.2)

            contentBody
        }
        .frame(maxHeight: .infinity)
    }

    @ViewBuilder
    private var contentBody: some View {
        switch activeTab {
        case .plan:
            planContent
        case .context:
            inspectorScrollContent { contextContent }
        case .capabilities:
            inspectorScrollContent { capabilitiesContent }
        case .execution:
            inspectorScrollContent { executionContent }
        case .hierarchy:
            inspectorScrollContent { hierarchyContent }
        }
    }

    private func inspectorScrollContent<Content: View>(
        @ViewBuilder _ content: () -> Content
    ) -> some View {
        ScrollView(.vertical, showsIndicators: true) {
            content()
                .padding(12)
        }
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 6) {
            ForEach(ACCInspectorTab.allCases) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        accState.inspectorState = .expanded(tab)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 11, weight: .semibold))
                        Text(tab.title)
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(activeTab == tab ? theme.resolved.accent.color : theme.mutedForeground.opacity(0.5))
                    .frame(maxWidth: .infinity, minHeight: 34)
                    .padding(.horizontal, 8)
                    .background(
                        activeTab == tab ? theme.resolved.accent.color.opacity(0.08) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Context Tab (compile-time truth)

    private var contextContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            inspectorSection("Attached Mentions") {
                if let compiled = diagnostics.compiledRequest {
                    if compiled.resolvedContextRefs.isEmpty {
                        emptyStateRow("No @mentions attached")
                    } else {
                        ForEach(compiled.resolvedContextRefs) { ref in
                            resolvedContextRow(ref)
                        }
                        if diagnostics.unresolvedMentionCount > 0 {
                            Text("\(diagnostics.unresolvedMentionCount) unresolved")
                                .font(.system(size: 10))
                                .foregroundStyle(.orange)
                        }
                    }
                } else if accState.activeMentions.isEmpty {
                    emptyStateRow("No @mentions attached")
                } else {
                    // Pre-compile: show parsed mentions (display only)
                    ForEach(accState.activeMentions) { mention in
                        HStack(spacing: 6) {
                            Image(systemName: "at")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(theme.mutedForeground.opacity(0.4))
                            Text(mention.resolvedLabel)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(theme.textSecondary)
                            Spacer()
                            Text("unresolved")
                                .font(.system(size: 9))
                                .foregroundStyle(theme.textTertiary)
                                .italic()
                        }
                    }
                }
            }

            inspectorSection("Active Slash Token") {
                // Prefer the compiled request's requested token (survives the
                // post-submit clearInput on the command bar). Fall back to live
                // UI state only when no submission has been compiled yet.
                if let compiledToken = diagnostics.requestedSlashToken {
                    HStack(spacing: 6) {
                        Image(systemName: compiledToken.icon)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(theme.resolved.accent.color)
                        Text("/\(compiledToken.displayName)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(theme.textPrimary)
                    }
                } else if let token = accState.activeSlashToken {
                    HStack(spacing: 6) {
                        Image(systemName: token.icon)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(theme.resolved.accent.color)
                        Text("/\(token.displayName)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(theme.textPrimary)
                    }
                } else {
                    emptyStateRow("No /command selected")
                }
            }

            if let ctx = diagnostics.compiledRequest?.notesContext {
                inspectorSection("Compiled Note Context") {
                    Text("\(ctx.count) chars resolved")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(theme.textSecondary)
                }
            }
        }
    }

    @ViewBuilder
    private func resolvedContextRow(_ ref: ResolvedContextRef) -> some View {
        HStack(spacing: 6) {
            Image(systemName: contextRefIcon(ref))
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(contextRefColor(ref))
            VStack(alignment: .leading, spacing: 1) {
                Text(ref.label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                if case .note(_, _, _, let body, let tokens) = ref, body != nil {
                    Text("~\(tokens) tokens")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(theme.textTertiary)
                } else if case .unresolved(_, let reason) = ref {
                    Text(reason)
                        .font(.system(size: 9))
                        .foregroundStyle(.orange)
                }
            }
            Spacer()
            Text(ref.kind)
                .font(.system(size: 9))
                .foregroundStyle(theme.textTertiary)
        }
    }

    private func contextRefIcon(_ ref: ResolvedContextRef) -> String {
        switch ref {
        case .note: "doc.text"
        case .agentTarget: "person.crop.rectangle"
        case .vaultScope: "tray.full"
        case .graphScope: "point.3.connected.trianglepath.dotted"
        case .folderScope: "folder"
        case .skillTarget: "wand.and.stars"
        case .unresolved: "exclamationmark.triangle"
        }
    }

    private func contextRefColor(_ ref: ResolvedContextRef) -> Color {
        switch ref {
        case .unresolved: .orange
        default: theme.resolved.accent.color
        }
    }

    // MARK: - Capabilities Tab (requested vs resolved)

    private var capabilitiesContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            inspectorSection("Brain") {
                requestedVsResolvedRow(
                    requested: diagnostics.requestedBrainLabel,
                    resolved: diagnostics.resolvedBrainLabel,
                    fallbackReason: diagnostics.runtimeFallbackReason
                )
            }

            inspectorSection("Tools") {
                HStack {
                    Text("\(diagnostics.allowedToolCount) / \(diagnostics.totalToolCount) allowed")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(theme.textPrimary)
                    Spacer()
                    if diagnostics.compiledRequest != nil {
                        Text("compiled")
                            .font(.system(size: 9))
                            .foregroundStyle(theme.textTertiary)
                    } else {
                        Text("uncompiled")
                            .font(.system(size: 9))
                            .foregroundStyle(theme.textTertiary)
                            .italic()
                    }
                }

                if let compiled = diagnostics.compiledRequest {
                    let allowedByAgent = Dictionary(
                        grouping: compiled.resolvedToolPermissions.filter { $0.decision == .allow },
                        by: \.agent
                    )
                    ForEach(allowedByAgent.keys.sorted(), id: \.self) { agent in
                        if let tools = allowedByAgent[agent] {
                            HStack(spacing: 6) {
                                Text(agent.isEmpty ? "other" : agent.capitalized)
                                    .font(.system(size: 11))
                                    .foregroundStyle(theme.textSecondary)
                                Spacer()
                                Text("\(tools.count)")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(theme.textTertiary)
                            }
                        }
                    }
                }
            }

            inspectorSection("Skills") {
                if accState.availableSkills.isEmpty {
                    emptyStateRow("No skills discovered")
                } else {
                    Text("\(accState.availableSkills.count) available")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(theme.textPrimary)
                }
            }

            inspectorSection("MCP Dispatcher") {
                HStack {
                    Text("Executions")
                        .font(.system(size: 11))
                        .foregroundStyle(theme.textSecondary)
                    Spacer()
                    Text("\(accState.mcpExecutionCount)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(theme.textTertiary)
                }
            }
        }
    }

    // MARK: - Plan Tab (requested vs resolved policy)

    private var planContent: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                inspectorSection("Document") {
                    Text("Structured plans and todo lists land here and stay directly editable.")
                        .font(.system(size: 11))
                        .foregroundStyle(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                inspectorSection("Command Intent") {
                    // Command Intent must survive the submit — read from the
                    // compiled request first, fall back to live UI state only
                    // while the user is still typing pre-submit.
                    if let compiledToken = diagnostics.requestedSlashToken {
                        HStack(spacing: 6) {
                            Image(systemName: compiledToken.icon)
                                .font(.system(size: 10))
                                .foregroundStyle(theme.resolved.accent.color)
                            Text(compiledToken.displayName)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(theme.textPrimary)
                        }
                    } else if let token = accState.activeSlashToken {
                        HStack(spacing: 6) {
                            Image(systemName: token.icon)
                                .font(.system(size: 10))
                                .foregroundStyle(theme.resolved.accent.color)
                            Text(token.displayName)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(theme.textPrimary)
                        }
                    } else {
                        emptyStateRow("No command selected")
                    }
                }

                inspectorSection("Operating Mode") {
                    requestedVsResolvedRow(
                        requested: diagnostics.requestedOperatingModeLabel,
                        resolved: diagnostics.effectiveOperatingModeLabel,
                        fallbackReason: nil
                    )
                }

                inspectorSection("Route") {
                    Text(diagnostics.resolvedRouteLabel)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(theme.textPrimary)
                }

                if !diagnostics.expertAllowlist.isEmpty {
                    inspectorSection("Experts") {
                        ForEach(diagnostics.expertAllowlist, id: \.self) { expert in
                            Text(expert)
                                .font(.system(size: 11))
                                .foregroundStyle(theme.textSecondary)
                        }
                    }
                }

                if let compiled = diagnostics.compiledRequest {
                    inspectorSection("Budgets") {
                        budgetRow("Turns", compiled.resolvedExecutionPolicy.maxTurns)
                        budgetRow("Tool calls", compiled.resolvedExecutionPolicy.maxToolCalls)
                        budgetRow("Reasoning steps", compiled.resolvedExecutionPolicy.maxReasoningSteps)
                        budgetRow("Output tokens", compiled.resolvedExecutionPolicy.maxOutputTokens)
                    }
                }
            }
            .padding(12)

            Divider().opacity(0.2)

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Plan Surface")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(theme.textPrimary)
                    Text("Switch between rendered document editing and raw markdown.")
                        .font(.system(size: 10))
                        .foregroundStyle(theme.textTertiary)
                }

                Spacer()

                MarkdownDocumentModeToggle(
                    mode: planDocumentPresentationModeBinding,
                    showsLabels: true
                )
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 8)

            Divider().opacity(0.2)

            AgentPlanEditorView(
                text: Binding(
                    get: { agentChat.planDocumentText },
                    set: { agentChat.userEditedPlanDocument($0) }
                ),
                pageId: agentChat.activeSessionId.map { "agent-plan-\($0)" } ?? "agent-plan-draft",
                presentationMode: planDocumentPresentationMode
            )
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func budgetRow(_ label: String, _ value: Int) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(theme.textSecondary)
            Spacer()
            Text("\(value)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(theme.textTertiary)
        }
    }

    // MARK: - Execution Tab (runtime truth)

    private var executionContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            inspectorSection("Status") {
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 6, height: 6)
                    Text(statusLabel)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(theme.textPrimary)
                    Spacer()
                    Text("Turn \(diagnostics.currentTurn)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(theme.textTertiary)
                }

                if let active = diagnostics.activeToolName {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.mini)
                        Text(active)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(theme.resolved.accent.color)
                    }
                }

                if let stop = diagnostics.stopReason {
                    HStack {
                        Text("stop")
                            .font(.system(size: 10))
                            .foregroundStyle(theme.textTertiary)
                        Spacer()
                        Text(stop)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(theme.textSecondary)
                    }
                }

                if let errClass = diagnostics.errorClass {
                    HStack {
                        Text("error")
                            .font(.system(size: 10))
                            .foregroundStyle(.red)
                        Spacer()
                        Text(errClass.rawValue)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.red)
                    }
                }
            }

            inspectorSection("Tokens") {
                VStack(alignment: .leading, spacing: 4) {
                    if diagnostics.tokenAccounting.maxContextTokens > 0 {
                        ProgressView(value: diagnostics.contextUsageFraction)
                            .tint(diagnostics.contextUsageFraction > 0.8 ? .orange : theme.resolved.accent.color)
                    }
                    HStack {
                        Text("in \(diagnostics.tokenAccounting.inputTokens)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(theme.textTertiary)
                        Spacer()
                        Text("out \(diagnostics.tokenAccounting.outputTokens)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(theme.textTertiary)
                    }
                }
            }

            inspectorSection("Tool History") {
                if diagnostics.toolHistory.isEmpty {
                    emptyStateRow("No tool calls yet")
                } else {
                    ForEach(diagnostics.toolHistory) { record in
                        HStack(spacing: 6) {
                            Image(systemName: record.isError ? "xmark.circle.fill" : "checkmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(record.isError ? .red : .green)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(record.toolName)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(theme.textPrimary)
                                Text("\(record.durationMs)ms")
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(theme.textTertiary)
                            }
                        }
                    }
                }
            }

            if !diagnostics.permissionDecisions.isEmpty {
                inspectorSection("Permissions") {
                    ForEach(diagnostics.permissionDecisions) { decision in
                        HStack(spacing: 6) {
                            Image(systemName: permissionIcon(decision.decision))
                                .font(.system(size: 10))
                                .foregroundStyle(permissionColor(decision.decision))
                            Text(decision.toolName)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(theme.textPrimary)
                            Spacer()
                            Text(decision.riskLevel)
                                .font(.system(size: 9))
                                .foregroundStyle(theme.textTertiary)
                        }
                    }
                }
            }

            if !diagnostics.compactionEvents.isEmpty {
                inspectorSection("Context Compaction") {
                    ForEach(diagnostics.compactionEvents) { event in
                        HStack {
                            Text("\(event.tokensBeforeCompaction) → \(event.messagesAfter.map(String.init) ?? "…") msgs")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(theme.textSecondary)
                        }
                    }
                }
            }

            if !diagnostics.fallbackEvents.isEmpty {
                inspectorSection("Fallbacks") {
                    ForEach(diagnostics.fallbackEvents) { event in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text(event.kind.rawValue)
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(.orange)
                                Text("\(event.from) → \(event.to)")
                                    .font(.system(size: 11))
                                    .foregroundStyle(theme.textPrimary)
                            }
                            Text(event.reason)
                                .font(.system(size: 10))
                                .foregroundStyle(theme.textTertiary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Hierarchy Tab

    private var hierarchyContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            inspectorSection("Topology") {
                Text("overseer → main agent → sub-agent")
                    .font(.system(size: 10))
                    .foregroundStyle(theme.textTertiary)
            }

            inspectorSection("Agents This Session") {
                if diagnostics.hierarchyNodes.isEmpty {
                    emptyStateRow("No sub-agents spawned")
                } else {
                    ForEach(diagnostics.hierarchyNodes) { node in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Image(systemName: hierarchyIcon(node.role))
                                    .font(.system(size: 10))
                                    .foregroundStyle(theme.resolved.accent.color)
                                Text(node.role.rawValue.replacingOccurrences(of: "_", with: " "))
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(theme.textPrimary)
                                Spacer()
                                Text("turns \(node.turns)")
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(theme.textTertiary)
                            }
                            Text(node.id)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(theme.textTertiary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                }
            }
        }
    }

    private func hierarchyIcon(_ role: HierarchicalAgentRole) -> String {
        switch role {
        case .overseer: "crown"
        case .mainAgent: "person.circle"
        case .subAgent: "person.2.circle"
        case .controlPlane: "gearshape.circle"
        }
    }

    // MARK: - Helpers

    private var statusColor: Color {
        switch diagnostics.state {
        case .idle: theme.mutedForeground.opacity(0.3)
        case .compiling: .yellow
        case .running: .green
        case .completed: theme.resolved.accent.color
        case .failed: .red
        }
    }

    private var statusLabel: String {
        switch diagnostics.state {
        case .idle: "Idle"
        case .compiling: "Compiling"
        case .running: "Executing"
        case .completed: "Completed"
        case .failed: "Failed"
        }
    }

    @ViewBuilder
    private func requestedVsResolvedRow(
        requested: String,
        resolved: String,
        fallbackReason: String?
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("requested")
                    .font(.system(size: 9))
                    .foregroundStyle(theme.textTertiary)
                Spacer()
                Text(requested)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
            }
            HStack {
                Text("resolved")
                    .font(.system(size: 9))
                    .foregroundStyle(theme.textTertiary)
                Spacer()
                Text(resolved)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)
            }
            if let reason = fallbackReason {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.turn.down.right")
                        .font(.system(size: 9))
                        .foregroundStyle(.orange)
                    Text(reason)
                        .font(.system(size: 9))
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private func permissionIcon(_ decision: CommandCenterExecutionDiagnostics.PermissionDecisionRecord.Decision) -> String {
        switch decision {
        case .approvedAutoReadOnly: "checkmark.shield.fill"
        case .approvedByUser: "checkmark.circle.fill"
        case .deniedByUser: "xmark.circle.fill"
        case .deniedByPolicy: "lock.shield.fill"
        }
    }

    private func permissionColor(_ decision: CommandCenterExecutionDiagnostics.PermissionDecisionRecord.Decision) -> Color {
        switch decision {
        case .approvedAutoReadOnly, .approvedByUser: .green
        case .deniedByUser, .deniedByPolicy: .red
        }
    }

    private func inspectorSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(theme.mutedForeground.opacity(0.5))

            content()
        }
    }

    private func emptyStateRow(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(theme.mutedForeground.opacity(0.4))
            .italic()
    }
}
