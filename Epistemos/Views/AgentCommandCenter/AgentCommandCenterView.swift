import Foundation
import SwiftUI

// MARK: - Agent Command Center View
// Top-level overlay that renders the Agent Command Center.
// The visual model intentionally follows a Claude Code-like terminal window:
// transcript first, quiet black chrome, compact status strip, and a docked
// command input. SwiftUI still owns the surface; Rust still owns execution.

struct AgentCommandCenterView: View {
    @Environment(AgentCommandCenterState.self) private var accState
    @Environment(AgentChatState.self) private var agentChat
    @Environment(UIState.self) private var ui
    @Environment(MCPBridge.self) private var mcpBridge
    @State private var landingStatsTab: ACCLandingStatsTab = .overview

    private var theme: EpistemosTheme { ui.theme }
    private let terminalBlack = Color(red: 0.035, green: 0.036, blue: 0.036)
    private let terminalPanel = Color(red: 0.085, green: 0.086, blue: 0.086)
    private let terminalInset = Color(red: 0.115, green: 0.116, blue: 0.116)
    private let terminalBorder = Color.white.opacity(0.10)
    private let mutedTerminalText = Color.white.opacity(0.58)
    private let terminalGreen = Color(red: 0.34, green: 0.78, blue: 0.42)
    private let terminalRed = Color(red: 0.82, green: 0.30, blue: 0.38)
    private let terminalYellow = Color(red: 0.86, green: 0.78, blue: 0.28)
    private let syntaxPink = Color(red: 0.93, green: 0.34, blue: 0.48)
    private let syntaxBlue = Color(red: 0.38, green: 0.56, blue: 0.96)
    private let syntaxViolet = Color(red: 0.65, green: 0.43, blue: 0.98)
    private let syntaxCyan = Color(red: 0.31, green: 0.82, blue: 0.94)

    private var disabledToolCount: Int {
        max(accState.toolToggles.count - accState.enabledToolNames.count, 0)
    }

    private var currentBrainLabel: String {
        accState.selectedBrain?.displayName ?? "Auto"
    }

    private var currentRuntimeLabel: String {
        var labels = [currentBrainLabel, accState.selectedOperatingMode.displayName]
        if let effort = accState.selectedNativeProviderEffort {
            labels.append(effort.displayName)
        }
        return labels.joined(separator: " · ")
    }

    private var greetingName: String {
        let fullName = NSFullUserName().trimmingCharacters(in: .whitespacesAndNewlines)
        let accountName = NSUserName().trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = fullName.isEmpty || fullName == accountName ? accountName : fullName
        guard let first = candidate.split(separator: " ").first else { return "Researcher" }
        return String(first)
    }

    private var agentPersonaLabel: String {
        switch accState.selectedOperatingMode {
        case .fast: "Navigator"
        case .thinking: "Researcher"
        case .pro: "Operator"
        case .agent: "Architect"
        }
    }

    private var isRightRailVisible: Bool {
        guard accState.presentationMode != .compact else { return false }
        if accState.presentationMode == .advanced { return true }
        if case .expanded = accState.inspectorState { return true }
        return false
    }

    private var windowMaxWidth: CGFloat {
        switch accState.presentationMode {
        case .compact: 760
        case .standard: 930
        case .advanced: 1_090
        }
    }

    private var windowMaxHeight: CGFloat {
        switch accState.presentationMode {
        case .compact: 580
        case .standard, .advanced: 680
        }
    }

    var body: some View {
        ZStack {
            terminalBackdrop
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        accState.dismiss()
                    }
                }

            terminalWindow
                .padding(40)
        }
        .onKeyPress(.escape) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                accState.dismiss()
            }
            return .handled
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.88), value: accState.inspectorState)
    }

    // MARK: - Shell

    private var terminalBackdrop: some View {
        ZStack {
            Color.black.opacity(0.86)
                .background(.ultraThinMaterial)

            RadialGradient(
                colors: [
                    theme.resolved.accent.color.opacity(0.12),
                    Color.clear,
                ],
                center: .top,
                startRadius: 120,
                endRadius: 760
            )
        }
    }

    private var terminalWindow: some View {
        VStack(spacing: 0) {
            terminalTitleBar

            Divider()
                .background(terminalBorder)

            HStack(spacing: 0) {
                commandArea
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if isRightRailVisible {
                    Divider()
                        .background(terminalBorder)

                    rightWorkspaceRail
                        .frame(width: 300)
                        .background(terminalPanel.opacity(0.78))
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }
        }
        .frame(maxWidth: windowMaxWidth, maxHeight: windowMaxHeight)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(terminalBlack.opacity(0.96))
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: .black.opacity(0.72), radius: 46, y: 18)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(terminalBorder, lineWidth: 1)
        }
    }

    private var terminalTitleBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                trafficLight(.red)
                trafficLight(.yellow)
                trafficLight(.green)
            }

            Image(systemName: "line.3.horizontal")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(mutedTerminalText.opacity(0.72))
                .padding(.leading, 8)

            Image(systemName: "folder")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.74))

            Text("Epistemos")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.82))

            Text("/")
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.34))

            Text("Agent Command Center")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(mutedTerminalText)

            Spacer()

            panelMenu
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
        .background(terminalBlack.opacity(0.82))
    }

    private var panelMenu: some View {
        Menu {
            Section("Panels") {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        accState.presentationMode = .standard
                        accState.inspectorState = .collapsed
                    }
                } label: {
                    panelMenuRow("Preview", icon: "play", selected: accState.presentationMode == .standard && accState.inspectorState == .collapsed)
                }

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        accState.presentationMode = .advanced
                        accState.inspectorState = .collapsed
                    }
                } label: {
                    panelMenuRow("Terminal", icon: "terminal", selected: accState.presentationMode == .advanced && accState.inspectorState == .collapsed)
                }

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        accState.presentationMode = .advanced
                        accState.inspectorState = .expanded(.execution)
                    }
                } label: {
                    panelMenuRow("Tasks", icon: "checklist", selected: isInspectorTab(.execution))
                }

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        accState.presentationMode = .advanced
                        accState.inspectorState = .expanded(.plan)
                    }
                } label: {
                    panelMenuRow("Plan", icon: "list.bullet.clipboard", selected: isInspectorTab(.plan))
                }
            }

            Section("View") {
                ForEach(ACCPresentationMode.allCases) { mode in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            selectPresentationMode(mode)
                        }
                    } label: {
                        panelMenuRow(mode.displayName, icon: mode.icon, selected: accState.presentationMode == mode)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: accState.presentationMode.icon)
                    .font(.system(size: 13, weight: .medium))
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .opacity(0.75)
            }
            .foregroundStyle(isRightRailVisible ? Color.white.opacity(0.84) : mutedTerminalText)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                isRightRailVisible ? Color.white.opacity(0.07) : Color.white.opacity(0.025),
                in: RoundedRectangle(cornerRadius: 7, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(isRightRailVisible ? terminalBorder.opacity(1.5) : terminalBorder, lineWidth: 0.7)
            }
        }
        .menuStyle(.borderlessButton)
        .help("Panels and View Mode")
    }

    private func panelMenuRow(_ title: String, icon: String, selected: Bool) -> some View {
        Label {
            HStack {
                Text(title)
                Spacer()
                if selected {
                    Image(systemName: "checkmark")
                }
            }
        } icon: {
            Image(systemName: icon)
        }
    }

    private func isInspectorTab(_ tab: ACCInspectorTab) -> Bool {
        if case .expanded(tab) = accState.inspectorState {
            return true
        }
        return false
    }

    private func selectPresentationMode(_ mode: ACCPresentationMode) {
        accState.presentationMode = mode
        switch mode {
        case .compact:
            accState.inspectorState = .collapsed
        case .standard:
            accState.inspectorState = .collapsed
        case .advanced:
            if case .collapsed = accState.inspectorState {
                accState.inspectorState = .expanded(.capabilities)
            }
        }
    }

    private func trafficLight(_ color: Color) -> some View {
        Circle()
            .fill(color.opacity(0.92))
            .frame(width: 11, height: 11)
    }

    // MARK: - Command Area

    private var commandArea: some View {
        VStack(spacing: 0) {
            transcriptArea
                .frame(maxHeight: .infinity)

            bottomCommandDock
        }
    }

    private var transcriptArea: some View {
        ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(alignment: .leading, spacing: 14) {
                if agentChat.hasMessages || agentChat.isStreaming {
                    ForEach(agentChat.messages) { message in
                        agentMessageRow(message)
                    }

                    if agentChat.isStreaming {
                        streamingRow
                    }
                } else {
                    emptyTranscript
                }
            }
            .padding(.horizontal, 60)
            .padding(.top, 28)
            .padding(.bottom, 26)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(terminalBlack)
    }

    private var emptyTranscript: some View {
        VStack(alignment: .leading, spacing: 18) {
            agentLandingHero

            if accState.presentationMode != .compact {
                agentStatsPanel
            }

            agentLandingHints
        }
        .frame(maxWidth: 620, alignment: .leading)
        .padding(.top, 8)
    }

    private var agentLandingHero: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Greetings, \(greetingName)")
                .font(AppDisplayTypography.font(size: 21, allowDisplayFont: true))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.94),
                            syntaxBlue.opacity(0.92),
                            syntaxViolet.opacity(0.86),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .shadow(color: syntaxBlue.opacity(0.22), radius: 14, y: 6)

            HStack(spacing: 7) {
                syntaxBadge(agentPersonaLabel.lowercased(), color: syntaxBlue)
                syntaxBadge("rust:authority", color: terminalGreen)
                syntaxBadge("trace:ready", color: syntaxCyan)
            }

            Text("Start a new agent session below. Epistemos will route models, tools, context, and permission gates from the same control plane.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(mutedTerminalText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var agentStatsPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                ForEach(ACCLandingStatsTab.allCases) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            landingStatsTab = tab
                        }
                    } label: {
                        Text(tab.title)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(landingStatsTab == tab ? Color.white.opacity(0.84) : mutedTerminalText)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(
                                landingStatsTab == tab ? Color.white.opacity(0.075) : Color.clear,
                                in: RoundedRectangle(cornerRadius: 5, style: .continuous)
                            )
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                Text("live")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(terminalGreen)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(terminalGreen.opacity(0.10), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            }

            switch landingStatsTab {
            case .overview:
                overviewStatsGrid
                activityHeatmap
            case .models:
                modelStatsChart
            }
        }
        .padding(10)
        .background(terminalPanel.opacity(0.74), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(terminalBorder.opacity(1.15), lineWidth: 0.7)
        }
        .frame(maxWidth: 560, alignment: .leading)
    }

    private var overviewStatsGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
            landingMetricCard("Turns", "\(agentChat.agentTurnCount)")
            landingMetricCard("Messages", "\(agentChat.messages.count)")
            landingMetricCard("Tools", "\(accState.enabledToolNames.count)")
            landingMetricCard("Disabled", "\(disabledToolCount)")
            landingMetricCard("Context", "\(agentChat.estimatedContextTokens.formatted())")
            landingMetricCard("Budget", "\(agentChat.maxContextTokens.formatted())")
            landingMetricCard("MCP tools", "\(accState.mcpToolCount)")
            landingMetricCard("Runs", "\(accState.mcpExecutionCount)")
        }
    }

    private func landingMetricCard(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(mutedTerminalText)
                .lineLimit(1)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.82))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
    }

    private var activityHeatmap: some View {
        VStack(alignment: .leading, spacing: 6) {
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(9), spacing: 3), count: 28), spacing: 3) {
                ForEach(0..<84, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(heatmapColor(for: index))
                        .frame(width: 9, height: 9)
                }
            }

            Text("Context reserve: \(Int((1 - agentChat.contextUsageFraction) * 100))% free · active model: \(currentBrainLabel)")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(mutedTerminalText.opacity(0.92))
        }
    }

    private func heatmapColor(for index: Int) -> Color {
        let seed = agentChat.messages.count + accState.enabledToolNames.count + accState.mcpExecutionCount
        let value = (index * 17 + seed * 11) % 9
        switch value {
        case 0...2: return Color.white.opacity(0.07)
        case 3...4: return syntaxBlue.opacity(0.24)
        case 5...6: return syntaxBlue.opacity(0.48)
        case 7: return syntaxViolet.opacity(0.56)
        default: return syntaxCyan.opacity(0.72)
        }
    }

    private var modelStatsChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(modelBars.enumerated()), id: \.offset) { _, bar in
                HStack(spacing: 8) {
                    Text(bar.name)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.72))
                        .lineLimit(1)
                        .frame(width: 132, alignment: .leading)

                    GeometryReader { proxy in
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(bar.color.opacity(0.26))
                            .overlay(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(bar.color)
                                    .frame(width: max(8, proxy.size.width * bar.fraction))
                            }
                    }
                    .frame(height: 10)

                    Text(bar.detail)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(mutedTerminalText)
                        .frame(width: 52, alignment: .trailing)
                }
            }
        }
    }

    private var modelBars: [ACCLandingModelBar] {
        let brains = accState.availableBrains.isEmpty ? [.placeholder(currentBrainLabel)] : accState.availableBrains.map { ACCLandingModelBar.Source.brain($0) }
        return brains.prefix(7).enumerated().map { index, source in
            let score = Double(max(1, 7 - index))
            return ACCLandingModelBar(
                name: source.name,
                detail: source.detail,
                fraction: score / 7.0,
                color: [syntaxBlue, syntaxViolet, syntaxCyan, terminalGreen][index % 4]
            )
        }
    }

    private var agentLandingHints: some View {
        VStack(alignment: .leading, spacing: 8) {
            terminalBullet("Use `/` for commands and modes")
            terminalBullet("Use `@` to attach notes, vault scope, graph context, or agents")
            terminalBullet("Tool permissions stay explicit and inspectable")
            terminalBullet("Rust remains the control plane")
        }
    }

    private func terminalBullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundStyle(mutedTerminalText)
            Text(text)
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.70))
        }
    }

    private var streamingRow: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text(agentChat.activeToolName ?? "thinking")
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(mutedTerminalText)
            Text("›")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(mutedTerminalText.opacity(0.55))
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func agentMessageRow(_ message: ChatMessage) -> some View {
        if message.role == .user {
            sentQueryRow(message)
        } else {
            assistantMessageRow(message)
        }
    }

    private func sentQueryRow(_ message: ChatMessage) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 7) {
                syntaxBadge("query.sent", color: syntaxBlue)
                syntaxBadge("role:user", color: syntaxViolet)
                syntaxBadge("permission:gated", color: terminalYellow)
                syntaxBadge("+intent", color: terminalGreen)
                syntaxBadge("-silentFallback", color: terminalRed)
            }

            Text(message.content)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.88))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .frame(maxWidth: 610, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            syntaxBlue.opacity(0.18),
                            syntaxViolet.opacity(0.16),
                            terminalPanel.opacity(0.72),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            syntaxCyan.opacity(0.52),
                            syntaxBlue.opacity(0.42),
                            syntaxViolet.opacity(0.46),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
        }
        .shadow(color: syntaxBlue.opacity(0.12), radius: 18, y: 8)
    }

    private func assistantMessageRow(_ message: ChatMessage) -> some View {
        if message.isError {
            return AnyView(turnFailureCard(message))
        }

        return AnyView(VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                executionStatusGlyph(.success)
                Text("Epistemos")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.78))

                syntaxBadge("trace:on", color: syntaxCyan)
                syntaxBadge("exit:0", color: terminalGreen)
            }

            Text(message.content)
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.76))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            inlineArtifactStack(for: message)
        }
        .padding(.leading, 12)
        .padding(.vertical, 3)
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(syntaxBlue.opacity(0.54))
                .frame(width: 2)
        })
    }

    private func syntaxBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color.opacity(0.11), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(color.opacity(0.22), lineWidth: 0.5)
            }
    }

    private func executionStatusGlyph(_ status: ACCTranscriptStatus) -> some View {
        ZStack {
            Circle()
                .fill(status.color.opacity(0.15))
            Image(systemName: status.icon)
                .font(.system(size: 8, weight: .black))
                .foregroundStyle(status.color)
        }
        .frame(width: 16, height: 16)
        .overlay {
            Circle()
                .strokeBorder(status.color.opacity(0.28), lineWidth: 0.7)
        }
    }

    private func turnFailureCard(_ message: ChatMessage) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 7) {
                executionStatusGlyph(.failure)
                Text(errorTitle(for: message.content))
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                Spacer()
                Text("exit:1")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(terminalRed.opacity(0.82))
            }
            .foregroundStyle(Color.white.opacity(0.88))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(terminalRed.opacity(0.92))

            Text(message.content)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.82))
                .textSelection(.enabled)
                .lineLimit(6)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 7) {
                Text("x")
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundStyle(terminalRed)
                Text(failureRecoveryHint(for: message.content))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(mutedTerminalText)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 10)
        }
        .frame(maxWidth: 610, alignment: .leading)
        .background(terminalPanel.opacity(0.72), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(terminalRed.opacity(0.72), lineWidth: 0.9)
        }
    }

    @ViewBuilder
    private func inlineArtifactStack(for message: ChatMessage) -> some View {
        let editedFiles = editedFileSummaries(from: message.content)
        if !message.artifacts.isEmpty || !editedFiles.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(editedFiles) { summary in
                    editedFileCard(summary)
                }

                ForEach(message.artifacts) { artifact in
                    inlineArtifactCard(artifact)
                }
            }
            .padding(.top, 2)
        }
    }

    @ViewBuilder
    private func inlineArtifactCard(_ artifact: Artifact) -> some View {
        switch artifact.kind {
        case .table, .csv:
            markdownTableCard(title: artifact.title, content: artifact.content)
        case .fileEdit:
            inlineDiffCard(title: artifact.title, content: artifact.content)
        case .codeBlock where artifact.language?.lowercased() == "diff" || looksLikeDiff(artifact.content):
            inlineDiffCard(title: artifact.title, content: artifact.content)
        default:
            codeArtifactCard(artifact)
        }
    }

    private func editedFileCard(_ summary: ACCEditedFileSummary) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "doc.text.fill.viewfinder")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(syntaxCyan)
                Text(summary.fileName)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.80))
                    .lineLimit(1)
                Spacer()
                diffStatPill("+\(summary.added)", color: terminalGreen)
                diffStatPill("-\(summary.removed)", color: terminalRed)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.035))

            HStack(spacing: 8) {
                Text("diff")
                    .foregroundStyle(syntaxPink)
                Text("--stat")
                    .foregroundStyle(syntaxBlue)
                Text(summary.fileName)
                    .foregroundStyle(mutedTerminalText)
                    .lineLimit(1)
            }
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .frame(maxWidth: 570, alignment: .leading)
        .background(terminalPanel.opacity(0.58), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(terminalBorder.opacity(1.3), lineWidth: 0.7)
        }
    }

    private func inlineDiffCard(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            artifactHeader(title: title, icon: "plus.forwardslash.minus", color: syntaxCyan)

            VStack(spacing: 0) {
                ForEach(Array(diffPreviewLines(from: content).enumerated()), id: \.offset) { _, line in
                    diffPreviewLine(line)
                }
            }
            .padding(.vertical, 6)
        }
        .frame(maxWidth: 570, alignment: .leading)
        .background(terminalPanel.opacity(0.62), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(terminalBorder.opacity(1.3), lineWidth: 0.7)
        }
    }

    private func markdownTableCard(title: String, content: String) -> some View {
        let rows = markdownTableRows(from: content)

        return VStack(alignment: .leading, spacing: 0) {
            artifactHeader(title: title, icon: "tablecells", color: syntaxViolet)

            VStack(spacing: 0) {
                ForEach(Array(rows.prefix(6).enumerated()), id: \.offset) { index, row in
                    markdownTableRow(row, isHeader: index == 0)
                }
            }
        }
        .frame(maxWidth: 570, alignment: .leading)
        .background(terminalPanel.opacity(0.62), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(terminalBorder.opacity(1.3), lineWidth: 0.7)
        }
    }

    private func markdownTableRow(_ row: [String], isHeader: Bool) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(row.prefix(4).enumerated()), id: \.offset) { _, cell in
                markdownTableCell(cell, isHeader: isHeader)
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(terminalBorder.opacity(0.85))
                .frame(height: 0.6)
        }
    }

    private func markdownTableCell(_ cell: String, isHeader: Bool) -> some View {
        Text(cell)
            .font(.system(size: 11, weight: isHeader ? .semibold : .regular, design: .rounded))
            .foregroundStyle(isHeader ? Color.white.opacity(0.82) : Color.white.opacity(0.66))
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .background(isHeader ? Color.white.opacity(0.035) : Color.clear)
            .overlay(alignment: .trailing) {
                Rectangle()
                    .fill(terminalBorder.opacity(0.85))
                    .frame(width: 0.6)
            }
    }

    private func codeArtifactCard(_ artifact: Artifact) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            artifactHeader(title: artifact.title, icon: artifact.kind.systemImage, color: syntaxBlue)

            Text(String(artifact.content.prefix(1_200)))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.68))
                .textSelection(.enabled)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: 570, alignment: .leading)
        .background(terminalPanel.opacity(0.62), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(terminalBorder.opacity(1.3), lineWidth: 0.7)
        }
    }

    private func artifactHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.78))
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.035))
    }

    private func diffPreviewLine(_ line: ACCDiffPreviewLine) -> some View {
        HStack(spacing: 0) {
            Text(line.prefix)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(line.color(green: terminalGreen, red: terminalRed, muted: mutedTerminalText))
                .frame(width: 18, alignment: .center)

            Text(line.text)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(line.color(green: terminalGreen, red: terminalRed, muted: Color.white.opacity(0.58)))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(line.background(green: terminalGreen, red: terminalRed))
    }

    private func diffStatPill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
    }

    private func errorTitle(for content: String) -> String {
        let lowered = content.lowercased()
        if lowered.contains("api") { return "API error" }
        if lowered.contains("permission") { return "Permission denied" }
        if lowered.contains("timeout") || lowered.contains("timed out") { return "Timeout" }
        if lowered.contains("rate") && lowered.contains("limit") { return "Rate limit" }
        return "Turn failed"
    }

    private func failureRecoveryHint(for content: String) -> String {
        let lowered = content.lowercased()
        if lowered.contains("busy") || lowered.contains("500") {
            return "Service is busy — try again in a moment, or switch to a different model."
        }
        if lowered.contains("permission") {
            return "Permission gate blocked the action. Inspect the request before retrying."
        }
        if lowered.contains("credential") || lowered.contains("api key") {
            return "Credential is missing or invalid. Check provider settings before retrying."
        }
        return "Inspect the trace, adjust the request, then retry."
    }

    private func editedFileSummaries(from content: String) -> [ACCEditedFileSummary] {
        let pattern = #"(?:Edited|Created|Modified)\s+([^\s]+)\s+\+(\d+)-(\d+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        let nsContent = content as NSString
        let matches = regex.matches(in: content, range: NSRange(location: 0, length: nsContent.length))
        var seen = Set<String>()

        return matches.compactMap { match in
            guard match.numberOfRanges == 4 else { return nil }
            let fileName = nsContent.substring(with: match.range(at: 1))
            let added = Int(nsContent.substring(with: match.range(at: 2))) ?? 0
            let removed = Int(nsContent.substring(with: match.range(at: 3))) ?? 0
            let key = "\(fileName):\(added):\(removed)"
            guard !seen.contains(key) else { return nil }
            seen.insert(key)
            return ACCEditedFileSummary(fileName: fileName, added: added, removed: removed)
        }
    }

    private func looksLikeDiff(_ content: String) -> Bool {
        content.contains("diff --git")
            || content.contains("\n@@")
            || (content.contains("\n+") && content.contains("\n-"))
    }

    private func diffPreviewLines(from content: String) -> [ACCDiffPreviewLine] {
        let lines = content
            .components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        let preview = lines.prefix(28).map(ACCDiffPreviewLine.init(raw:))
        return preview.isEmpty ? [ACCDiffPreviewLine(raw: "No diff lines available")] : preview
    }

    private func markdownTableRows(from content: String) -> [[String]] {
        content
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { line in
                line.hasPrefix("|")
                    && line.hasSuffix("|")
                    && !line.replacingOccurrences(of: "|", with: "")
                        .trimmingCharacters(in: CharacterSet(charactersIn: "-: "))
                        .isEmpty
            }
            .map { line in
                line
                    .dropFirst()
                    .dropLast()
                    .split(separator: "|", omittingEmptySubsequences: false)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
            }
    }

    // MARK: - Right Workspace Rail

    @ViewBuilder
    private var rightWorkspaceRail: some View {
        if case .expanded = accState.inspectorState {
            InspectorPanelView()
                .transition(.opacity.combined(with: .move(edge: .trailing)))
        } else {
            agentWorkspaceRail
                .transition(.opacity.combined(with: .move(edge: .trailing)))
        }
    }

    private var agentWorkspaceRail: some View {
        VStack(spacing: 0) {
            if agentChat.hasMessages || agentChat.isStreaming {
                terminalPane
                    .frame(minHeight: 220)

                railDivider

                filePreviewPane
            } else {
                filePreviewPane

                railDivider

                terminalPane
                    .frame(minHeight: 210)
            }
        }
    }

    private var railDivider: some View {
        Rectangle()
            .fill(terminalBorder)
            .frame(height: 0.6)
    }

    private var filePreviewPane: some View {
        VStack(spacing: 0) {
            railHeader(title: "File", subtitle: "/AgentCommandCenter/session.preview")

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 7) {
                    syntaxLine(1, [("import", syntaxPink), (" SwiftUI", syntaxViolet)])
                    syntaxLine(2, [("@mode", syntaxPink), (" .", mutedTerminalText), ("agent", syntaxBlue)])
                    syntaxLine(3, [("@brain", syntaxPink), (" \"\(currentBrainLabel)\"", terminalGreen)])
                    syntaxLine(4, [("let", syntaxPink), (" route", Color.white.opacity(0.62)), (" = ", mutedTerminalText), ("\"rust_control_plane\"", terminalGreen)])
                    syntaxLine(5, [("guard", syntaxPink), (" noSilentFallback", syntaxBlue), (" else", syntaxPink), (" { deny() }", Color.white.opacity(0.62))])
                    syntaxLine(6, [("trace", syntaxBlue), (".append", syntaxViolet), ("(\"evidence\")", terminalGreen)])
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var terminalPane: some View {
        VStack(spacing: 0) {
            railHeader(title: "Terminal", subtitle: "jojo@epistemos Agent")

            VStack(alignment: .leading, spacing: 10) {
                terminalLine("jojo@Epistemos %", color: Color.white.opacity(0.74))
                terminalLine(agentChat.isStreaming ? "streaming \(agentChat.activeToolName ?? "tokens")" : "ready -- waiting for command", color: agentChat.isStreaming ? terminalYellow : mutedTerminalText)
                terminalLine("tools +\(accState.enabledToolNames.count) -\(disabledToolCount)", color: terminalGreen)
                terminalLine("mode \(accState.selectedOperatingMode.displayName.lowercased())", color: syntaxBlue)

                Spacer(minLength: 0)
            }
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private func railHeader(title: String, subtitle: String) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.78))

                Spacer()

                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(mutedTerminalText.opacity(0.75))

                Image(systemName: "sidebar.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(mutedTerminalText.opacity(0.75))
            }
            .padding(.horizontal, 12)
            .frame(height: 38)
            .background(Color.white.opacity(0.025))

            HStack {
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(mutedTerminalText)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 12)
            .frame(height: 28)
            .background(Color.white.opacity(0.035))
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(terminalBorder)
                .frame(height: 0.6)
        }
    }

    private func syntaxLine(_ number: Int, _ segments: [(String, Color)]) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\(number)")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(mutedTerminalText.opacity(0.55))
                .frame(width: 22, alignment: .trailing)

            HStack(spacing: 0) {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                    Text(segment.0)
                        .foregroundStyle(segment.1)
                }
            }
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .lineLimit(1)
        }
    }

    private func terminalLine(_ text: String, color: Color) -> some View {
        Text(text)
            .foregroundStyle(color)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Bottom Dock

    private var bottomCommandDock: some View {
        VStack(spacing: 8) {
            if accState.presentationMode != .compact {
                commandSessionStrip
            }

            CommandBarView()

            commandFooter
        }
        .padding(12)
        .background {
            Rectangle()
                .fill(terminalBlack.opacity(0.86))
                .background(.ultraThinMaterial)
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(terminalBorder)
                .frame(height: 0.6)
        }
    }

    private var commandSessionStrip: some View {
        HStack(spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 12, weight: .medium))
                Text("agent")
                Text("←")
                    .foregroundStyle(mutedTerminalText.opacity(0.65))
                Text("main")
            }
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundStyle(Color.white.opacity(0.72))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(terminalInset, in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            Spacer()

            HStack(spacing: 0) {
                Text("+\(accState.enabledToolNames.count)")
                    .foregroundStyle(terminalGreen)
                Text(" −\(disabledToolCount)")
                    .foregroundStyle(terminalRed)
            }
            .font(.system(size: 12, weight: .bold, design: .monospaced))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(terminalInset, in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    accState.inspectorState = .expanded(.plan)
                }
            } label: {
                HStack(spacing: 5) {
                    Text("Inspect")
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                }
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.74))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(terminalInset, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private var commandFooter: some View {
        HStack(spacing: 12) {
            HStack(spacing: 5) {
                Text("permission")
                    .foregroundStyle(syntaxPink)
                Text("gates")
                    .foregroundStyle(syntaxBlue)
                Text("active")
                    .foregroundStyle(terminalYellow)
            }
            .font(.system(size: 12, weight: .semibold, design: .monospaced))

            Image(systemName: "doc.on.doc")
            Image(systemName: "plus")
            Image(systemName: "mic")
            Image(systemName: "chevron.down")

            Spacer()

            Text(currentRuntimeLabel)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(mutedTerminalText)

            Circle()
                .strokeBorder(mutedTerminalText.opacity(0.45), lineWidth: 1.4)
                .frame(width: 11, height: 11)
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(mutedTerminalText.opacity(0.72))
        .padding(.horizontal, 6)
    }
}

private enum ACCTranscriptStatus {
    case success
    case failure

    var icon: String {
        switch self {
        case .success: "checkmark"
        case .failure: "xmark"
        }
    }

    var color: Color {
        switch self {
        case .success: Color(red: 0.34, green: 0.78, blue: 0.42)
        case .failure: Color(red: 0.82, green: 0.30, blue: 0.38)
        }
    }
}

private enum ACCLandingStatsTab: String, CaseIterable, Identifiable {
    case overview
    case models

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: "Overview"
        case .models: "Models"
        }
    }
}

private struct ACCLandingModelBar {
    enum Source {
        case brain(ACCBrainSelection)
        case placeholder(String)

        var name: String {
            switch self {
            case .brain(let brain): brain.displayName
            case .placeholder(let label): label
            }
        }

        var detail: String {
            switch self {
            case .brain(.local(_, _, let thinking, let vision, let tools)):
                let count = [thinking, vision, tools].filter { $0 }.count
                return "\(count)/3"
            case .brain(.appleIntelligence):
                return "local"
            case .brain(.cloud):
                return "cloud"
            case .placeholder:
                return "auto"
            }
        }
    }

    let name: String
    let detail: String
    let fraction: Double
    let color: Color
}

private struct ACCEditedFileSummary: Identifiable {
    let fileName: String
    let added: Int
    let removed: Int

    var id: String { "\(fileName):\(added):\(removed)" }
}

private struct ACCDiffPreviewLine {
    enum Kind {
        case added
        case removed
        case hunk
        case context
    }

    let kind: Kind
    let text: String

    init(raw: String) {
        if raw.hasPrefix("+") && !raw.hasPrefix("+++") {
            kind = .added
            text = String(raw.dropFirst())
        } else if raw.hasPrefix("-") && !raw.hasPrefix("---") {
            kind = .removed
            text = String(raw.dropFirst())
        } else if raw.hasPrefix("@@") || raw.hasPrefix("diff ") || raw.hasPrefix("+++") || raw.hasPrefix("---") {
            kind = .hunk
            text = raw
        } else {
            kind = .context
            text = raw
        }
    }

    var prefix: String {
        switch kind {
        case .added: "+"
        case .removed: "-"
        case .hunk: ">"
        case .context: " "
        }
    }

    func color(green: Color, red: Color, muted: Color) -> Color {
        switch kind {
        case .added: green
        case .removed: red
        case .hunk: Color(red: 0.31, green: 0.82, blue: 0.94)
        case .context: muted
        }
    }

    func background(green: Color, red: Color) -> Color {
        switch kind {
        case .added: green.opacity(0.08)
        case .removed: red.opacity(0.08)
        case .hunk: Color(red: 0.31, green: 0.82, blue: 0.94).opacity(0.06)
        case .context: Color.clear
        }
    }
}
