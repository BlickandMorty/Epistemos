import Foundation
import SwiftData
import SwiftUI

#if !EPISTEMOS_APP_STORE && canImport(AgentClone)
import AgentClone

private enum AgentFusionChatLayout {
    static let toolbarMinHeight: CGFloat = 50
    static let messageColumnMaxWidth: CGFloat = 760
    static let composerMaxWidth: CGFloat = 860
    static let composerHorizontalPadding: CGFloat = 11
    static let composerTopPadding: CGFloat = 9
    static let composerBottomPadding: CGFloat = 7
    static let composerControlRowTopPadding: CGFloat = 6
    static let transcriptSpacing: CGFloat = 28
    static let transcriptBottomReserve: CGFloat = 190
    static let compactTranscriptBottomReserve: CGFloat = 170
    static let userBubbleLeadingReserve: CGFloat = 200
}

struct AgentCloneChatHostSurface: View {
    let context: AgentCloneAppContextSnapshot
    let onSyncHostContext: () -> Void

    @Environment(UIState.self) private var ui
    @Environment(AgentChatState.self) private var agentChat
    @Environment(InferenceState.self) private var inference
    @Environment(AgentCommandCenterState.self) private var agentCommandCenter
    @Environment(ChatApprovalQueue.self) private var chatApprovalQueue
    @Environment(VaultSyncService.self) private var vaultSync
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openSettings) private var openSettings
    @AppStorage(MainChatOperatingModePreference.defaultsKey)
    private var bridgeOperatingModeRaw = EpistemosOperatingMode.fast.rawValue
    @State private var showSessionRail = false
    @State private var showContextRail = false
    @State private var showCompactSessionRail = false
    @State private var showCompactContextRail = false
    @State private var showBridgeRuntimePicker = false
    @State private var showBridgeSlashMenu = false
    @State private var bridgeSlashFilter = ""
    @State private var selectedBridgeSlashItem: ComposerSlashCommandItem?
    @State private var showBridgeMentionDropdown = false
    @State private var bridgeMentionFilter = ""
    @State private var bridgeReferenceSearch = ComposerReferenceSearchState()
    @State private var bridgeContextAttachments: [ContextAttachment] = []
    @State private var bridgePromptText = ""
    @State private var mirroredAgentCloneMessages: [AgentCloneMirroredMessage] = []
    @State private var mirrorTask: Task<Void, Never>?
    @FocusState private var bridgePromptFocused: Bool

    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.width < 980
            let compactSessionWidth = min(max(geometry.size.width - 64, 220), 286)
            let compactContextWidth = min(max(geometry.size.width - 64, 240), 320)
            VStack(spacing: 0) {
                chatHostToolbar(compact: compact)

                HStack(spacing: 0) {
                    if showSessionRail, !compact {
                        sessionRail {
                            showSessionRail = false
                        }
                            .frame(width: 228)
                            .transition(.move(edge: .leading).combined(with: .opacity))
                    }

                    agentCloneContent(compact: compact)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    if showContextRail, !compact {
                        contextRail {
                            showContextRail = false
                        }
                            .frame(width: 286)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .overlay(alignment: .leading) {
                    if compact && showCompactSessionRail {
                        sessionRail {
                            showCompactSessionRail = false
                        }
                        .frame(width: compactSessionWidth)
                        .padding(.top, 8)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                    }
                }
                .overlay(alignment: .trailing) {
                    if compact && showCompactContextRail {
                        contextRail {
                            showCompactContextRail = false
                        }
                        .frame(width: compactContextWidth)
                        .padding(.top, 8)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
            }
            .background(theme.chatSurface)
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: showSessionRail)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: showContextRail)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: showCompactSessionRail)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: showCompactContextRail)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: showBridgeRuntimePicker)
        .onAppear {
            onSyncHostContext()
            agentCommandCenter.refreshSkillCatalog()
        }
        .onDisappear {
            mirrorTask?.cancel()
            mirrorTask = nil
        }
    }

    private func agentCloneContent(compact: Bool) -> some View {
        ZStack {
            agentCloneFoundationMount
            bridgeConversationCanvas(compact: compact)
        }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.chatSurface)
            .overlay(alignment: .bottom) {
                bridgeComposerDock(compact: compact)
                    .padding(.horizontal, compact ? 12 : 16)
                    .padding(.bottom, compact ? 12 : 16)
            }
    }

    private var agentCloneFoundationMount: some View {
        AgentClone.ContentView()
            .opacity(0.001)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private func bridgeConversationCanvas(compact: Bool) -> some View {
        ZStack {
            theme.chatSurface

            if shouldShowBridgeEmptyLandingMark {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    if let summary = bridgeActiveRecentPortalSession,
                       shouldShowBridgeSessionResumeMark {
                        bridgeSessionResumeMark(summary, compact: compact)
                            .offset(y: compact ? -42 : -58)
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    } else {
                        bridgeEmptyLandingMark(compact: compact)
                            .offset(y: compact ? -42 : -58)
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))
                            .allowsHitTesting(false)
                    }
                    Spacer(minLength: compact ? 140 : 170)
                }
            } else {
                ScrollView {
                    bridgeTranscriptRunway(compact: compact)
                        .padding(.horizontal, compact ? 12 : 24)
                        .padding(.top, compact ? 28 : 46)
                        .padding(.bottom, compact ? AgentFusionChatLayout.compactTranscriptBottomReserve : AgentFusionChatLayout.transcriptBottomReserve)
                        .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    private var shouldShowBridgeEmptyLandingMark: Bool {
        !agentChat.hasMessages
            && !agentChat.isStreaming
            && !agentChat.isAgentExecuting
            && mirroredAgentCloneMessages.isEmpty
    }

    private var bridgeActiveRecentPortalSession: AgentPortalSessionSummary? {
        guard let activeSessionId = agentChat.activeSessionId else { return nil }
        return agentChat.recentPortalSessions.first { $0.id == activeSessionId }
    }

    private var shouldShowBridgeSessionResumeMark: Bool {
        guard let summary = bridgeActiveRecentPortalSession else { return false }
        return summary.messageCount > 0 || summary.promptPreview != nil
    }

    private func bridgeEmptyLandingMark(compact: Bool) -> some View {
        VStack(spacing: 8) {
            MotionTitle(
                text: context.appName,
                font: .system(size: compact ? 30 : 34, weight: .semibold),
                color: theme.textPrimary
            )
                .lineLimit(1)

            Text(bridgeEmptyLandingSubtitle)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(theme.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: compact ? 360 : 460)
    }

    private func bridgeSessionResumeMark(
        _ summary: AgentPortalSessionSummary,
        compact: Bool
    ) -> some View {
        let contextLine = recentPortalSessionContextLine(summary, compact: compact)

        return VStack(spacing: 12) {
            VStack(spacing: 5) {
                MotionTitle(
                    text: "Session ready",
                    font: .system(size: compact ? 27 : 31, weight: .semibold),
                    color: theme.textPrimary
                )
                    .lineLimit(1)

                Text(recentPortalSessionDetail(summary))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
            }

            if let promptPreview = summary.promptPreview?.trimmingCharacters(in: .whitespacesAndNewlines),
               !promptPreview.isEmpty {
                Text(clippedInline(promptPreview, limit: compact ? 76 : 112))
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)
            }

            if !contextLine.isEmpty {
                Text(contextLine)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)
            }

            HStack(spacing: 8) {
                Button {
                    bridgePromptFocused = true
                } label: {
                    Label("Continue", systemImage: "arrow.turn.down.left")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.textPrimary)

                Button {
                    toggleContextRail(compact: compact)
                } label: {
                    Label("Context", systemImage: "sidebar.right")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.textPrimary)

                Text(recentPortalSessionMeta(summary))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(theme.chatSurface.opacity(0.68), in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(theme.border.opacity(0.48), lineWidth: 1)
        }
        .frame(maxWidth: compact ? 380 : 500)
    }

    private var bridgeEmptyLandingSubtitle: String {
        let portal = context.portalContext.portal.label.lowercased()
        return portal == "main" ? "ready" : "\(portal) ready"
    }

    private var bridgeAgentStatusLabel: String {
        if bridgePendingApproval != nil {
            return "approval"
        }
        if agentChat.isAgentExecuting {
            return "running"
        }
        if agentChat.isThinkingActive {
            return "thinking"
        }
        if agentChat.isStreaming {
            return "live"
        }
        if agentChat.activeSessionId != nil {
            return "session ready"
        }
        return "ready"
    }

    private var bridgeAgentStatusSymbol: String {
        if bridgePendingApproval != nil {
            return "shield.lefthalf.filled.badge.checkmark"
        }
        if agentChat.isAgentExecuting {
            return "wrench.and.screwdriver"
        }
        if agentChat.isThinkingActive {
            return "brain.head.profile"
        }
        if agentChat.isStreaming {
            return "waveform"
        }
        if agentChat.activeSessionId != nil {
            return "clock.arrow.circlepath"
        }
        return "sparkles"
    }

    private func chatHostToolbar(compact: Bool) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(context.appName)
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                Text(bridgeAgentStatusLabel)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            if !compact {
                Text(context.portalContext.portal.label)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(theme.chatSurface.opacity(0.58), in: RoundedRectangle(cornerRadius: 6))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(theme.border.opacity(0.44), lineWidth: 1)
                    }
            }

            sessionControlButton(compact: compact)
            modelContextButton(compact: compact)
            railControlButtons(compact: compact)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: AgentFusionChatLayout.toolbarMinHeight)
        .background(theme.chatSurface.opacity(0.88))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(theme.border.opacity(0.64))
                .frame(height: 1)
        }
    }

    private func modelContextButton(compact: Bool) -> some View {
        Button {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.16)) {
                showBridgeRuntimePicker.toggle()
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "cpu")
                    .font(.system(size: 11, weight: .semibold))
                Text("model")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
            }
            .foregroundStyle(showBridgeRuntimePicker ? theme.uiAccent : theme.textPrimary)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(theme.chatSurface.opacity(0.72), in: RoundedRectangle(cornerRadius: 7))
            .overlay {
                RoundedRectangle(cornerRadius: 7)
                    .stroke(theme.border.opacity(showBridgeRuntimePicker ? 0.78 : 0.6), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .help("Model picker")
    }

    private func sessionControlButton(compact: Bool) -> some View {
        Button {
            toggleSessionRail(compact: compact)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 11, weight: .semibold))
                Text("session")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                Text(clippedSession(bridgeVisibleSessionId))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
            }
            .foregroundStyle(theme.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(theme.chatSurface.opacity(0.72), in: RoundedRectangle(cornerRadius: 7))
            .overlay {
                RoundedRectangle(cornerRadius: 7)
                    .stroke(theme.border.opacity(0.6), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .help("Session rail")
    }

    @ViewBuilder
    private func bridgeTranscriptRunway(compact: Bool) -> some View {
        if agentChat.hasMessages || agentChat.isStreaming || agentChat.isAgentExecuting {
            LazyVStack(alignment: .leading, spacing: AgentFusionChatLayout.transcriptSpacing) {
                ForEach(recentBridgeMessages) { message in
                    bridgeTranscriptRow(message)
                }

                ForEach(mirroredAgentCloneMessages.suffix(3)) { message in
                    bridgeMirroredRuntimeRow(message)
                }

                if let pendingApproval = bridgePendingApproval {
                    bridgePendingApprovalRow(pendingApproval)
                }

                if agentChat.isAgentExecuting {
                    bridgeActiveToolRow(
                        name: agentChat.activeToolName,
                        inputJson: agentChat.activeToolInputJson
                    )
                }

                if agentChat.isStreaming, !agentChat.streamingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    bridgeStreamingRow(agentChat.streamingText)
                }
            }
            .frame(maxWidth: compact ? .infinity : AgentFusionChatLayout.messageColumnMaxWidth)
        }
    }

    private func bridgeComposerDock(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            bridgeComposerContextBar
                .padding(.bottom, 8)

            bridgeContextAttachmentChips
                .padding(.bottom, bridgeContextAttachments.isEmpty ? 0 : 7)

            bridgePortalActionChips
                .padding(.bottom, bridgeApprovedActionChips.isEmpty ? 0 : 7)

            HStack(alignment: .bottom, spacing: 10) {
                TextField("Ask anything... Type @ for notes or chats", text: $bridgePromptText, axis: .vertical)
                    .font(.system(size: compact ? 15 : 17, weight: .regular, design: .monospaced))
                    .textFieldStyle(.plain)
                    .lineLimit(1...5)
                    .focused($bridgePromptFocused)
                    .onSubmit(submitBridgePromptFromDock)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(theme.chatSurface.opacity(0.7), in: RoundedRectangle(cornerRadius: 7))
                    .overlay {
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(theme.border.opacity(0.42), lineWidth: 1)
                    }
                    .onChange(of: bridgePromptText) { _, newValue in
                        handleBridgePromptTextChange(newValue)
                    }
                    .overlay(alignment: .topLeading) {
                        if showBridgeMentionDropdown {
                            ComposerReferencePopover(
                                isPresented: $showBridgeMentionDropdown,
                                results: bridgeMentionSearchResults,
                                query: $bridgeMentionFilter,
                                manifest: ambientManifest,
                                modelContext: modelContext,
                                idealWidth: ComposerReferencePopoverStyle.mention.idealWidth,
                                maxHeight: ComposerReferencePopoverStyle.mention.maxHeight,
                                style: .mention,
                                autofocusSearchField: false,
                                onDismiss: dismissBridgeReferencePopover,
                                onSelect: attachBridgeMentionReference
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .transition(.opacity)
                        }
                    }

                Button(action: submitBridgePromptFromDock) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(canSubmitBridgePrompt ? theme.chatSurface : theme.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(bridgeSendButtonBackground, in: RoundedRectangle(cornerRadius: 7))
                        .overlay {
                            RoundedRectangle(cornerRadius: 7)
                                .stroke(theme.border.opacity(canSubmitBridgePrompt ? 0.0 : 0.42), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .disabled(!canSubmitBridgePrompt)
                .help("Send")
            }

            if showBridgeRuntimePicker {
                InlineRuntimePickerPanel(
                    inference: inference,
                    operatingMode: bridgeOperatingModeBinding,
                    onPicked: {
                        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.16)) {
                            showBridgeRuntimePicker = false
                        }
                    },
                    onOpenSettings: { openSettings() },
                    showsSettingsFooter: true
                )
                .frame(maxHeight: compact ? 300 : 420)
                .padding(.top, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            HStack(alignment: .center, spacing: 8) {
                Button {
                    openBridgeSlashCommandMenu()
                } label: {
                    Label(selectedBridgeSlashItem.map { "/\($0.rawValue)" } ?? "/", systemImage: "command")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(showBridgeSlashMenu ? theme.uiAccent : theme.textPrimary)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
                .help(selectedBridgeSlashItem?.helpText ?? "Commands and skills")
                .popover(isPresented: $showBridgeSlashMenu, arrowEdge: .top) {
                    SlashCommandPopover(
                        items: supportedBridgeSlashItems,
                        filter: bridgeSlashFilter,
                        selectedItem: selectedBridgeSlashItem,
                        onSelect: applyBridgeSlashItem
                    )
                }

                Button {
                    insertBridgeMentionToken()
                } label: {
                    Label("@", systemImage: "at")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(showBridgeMentionDropdown ? theme.uiAccent : theme.textPrimary)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
                .help("Attach notes")

                Button {
                    showBridgeRuntimePicker.toggle()
                } label: {
                    Label(bridgeRuntimeTierLabel, systemImage: "cpu")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(showBridgeRuntimePicker ? theme.uiAccent : theme.textPrimary)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
                .help("Model picker")

                Spacer(minLength: 0)

                Button {
                    toggleSessionRail(compact: compact)
                } label: {
                    Label(clippedSession(bridgeVisibleSessionId), systemImage: "clock")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.textSecondary)
                .help("Session")

                ComposerMicButton { transcript in
                    appendBridgeVoiceTranscript(transcript)
                }
                .frame(width: 26, height: 26)

                Button {
                    startNewBridgeSession()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(theme.textSecondary)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("New session")
            }
            .padding(.top, AgentFusionChatLayout.composerControlRowTopPadding)
        }
        .padding(.horizontal, AgentFusionChatLayout.composerHorizontalPadding)
        .padding(.top, AgentFusionChatLayout.composerTopPadding)
        .padding(.bottom, AgentFusionChatLayout.composerBottomPadding)
        .frame(maxWidth: compact ? .infinity : AgentFusionChatLayout.composerMaxWidth)
        .background(theme.chatSurface.opacity(0.94), in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(theme.border.opacity(0.58), lineWidth: 1)
        }
    }

    @ViewBuilder
    private var bridgeContextAttachmentChips: some View {
        if !bridgeContextAttachments.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(bridgeContextAttachments) { attachment in
                        HStack(spacing: 5) {
                            Image(systemName: attachment.systemImageName)
                                .font(.system(size: 10, weight: .semibold))
                            Text(attachment.title)
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .lineLimit(1)
                            Button {
                                removeBridgeContextAttachment(attachment.id)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Remove \(attachment.title)")
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(theme.textSecondary.opacity(0.08), in: Capsule())
                        .foregroundStyle(theme.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private var bridgePortalActionChips: some View {
        let actions = bridgeActionDescriptors
        if !actions.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(actions, id: \.id) { action in
                        Button {
                            appendBridgeActionIntent(action)
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: bridgeActionSystemImage(action))
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
                            .background(bridgeActionChipFill(action), in: Capsule())
                            .foregroundStyle(action.requiresApproval ? theme.textPrimary : theme.uiAccent)
                        }
                        .buttonStyle(.plain)
                        .help(bridgeActionHelp(action))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var bridgeComposerContextBar: some View {
        Button {
            toggleBridgeAllNotesContext()
        } label: {
            HStack(spacing: 9) {
                Image(systemName: "shield")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(bridgeAllNotesContextAttached ? theme.uiAccent : theme.textSecondary)
                    .frame(width: 16, height: 16)

                Text("Read + Search vault")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(bridgeAllNotesContextAttached ? theme.uiAccent : theme.textPrimary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(theme.chatSurface.opacity(0.68), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(theme.border.opacity(0.44), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .help(bridgeAllNotesContextAttached ? "Remove all-notes context" : "Attach all notes")
    }

    private func bridgeMirroredRuntimeRow(_ message: AgentCloneMirroredMessage) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: message.role == .assistant ? "sparkles" : "wrench.and.screwdriver")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.uiAccent)
                .frame(width: 15, height: 15)

            VStack(alignment: .leading, spacing: 3) {
                Text(message.role == .assistant ? "agent" : "tool")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(theme.textSecondary)
                Text(clippedTranscriptText(message.text))
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(3)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func bridgeActiveToolRow(name: String?, inputJson: String?) -> some View {
        let toolName = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedToolName = (toolName?.isEmpty == false) ? toolName! : "tool"
        let surface = ToolActivityNarrator.surface(name: resolvedToolName)
        let phrase = ToolActivityNarrator.phrase(name: resolvedToolName, inputJson: inputJson)
            ?? "Running \(resolvedToolName)"

        return HStack(alignment: .top, spacing: 9) {
            Image(systemName: surface.symbolName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.uiAccent)
                .frame(width: 17, height: 17)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(surface.badgeTitle.lowercased())
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(theme.uiAccent)
                    Text("running")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(theme.textSecondary)
                }

                Text(phrase)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(theme.uiAccent.opacity(0.07), in: RoundedRectangle(cornerRadius: 9))
        .overlay {
            RoundedRectangle(cornerRadius: 9)
                .stroke(theme.uiAccent.opacity(0.18), lineWidth: 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var bridgePendingApproval: ApprovalModalView.PendingApproval? {
        guard let approval = chatApprovalQueue.pendingApproval else { return nil }
        guard let activeSessionId = agentChat.activeSessionId else { return approval }
        return approval.sessionId == activeSessionId ? approval : nil
    }

    private func bridgePendingApprovalRow(_ approval: ApprovalModalView.PendingApproval) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.uiAccent)
                .frame(width: 17, height: 17)

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    Text("approval")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(theme.uiAccent)
                    if let authority = approval.authorityCategoryLabel, !authority.isEmpty {
                        Text(authority.lowercased())
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(theme.textSecondary)
                            .lineLimit(1)
                    }
                }

                Text(approval.toolName)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)

                Text(bridgeApprovalDetail(approval))
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(3)
                    .truncationMode(.middle)
                    .textSelection(.enabled)

                HStack(spacing: 7) {
                    bridgeApprovalDecisionButton(
                        title: "Allow",
                        systemImage: "checkmark",
                        approval: approval,
                        decision: .approveOnce
                    )
                    bridgeApprovalDecisionButton(
                        title: "Always",
                        systemImage: "checkmark.shield",
                        approval: approval,
                        decision: .approveAlways
                    )
                    bridgeApprovalDecisionButton(
                        title: "Deny",
                        systemImage: "xmark",
                        approval: approval,
                        decision: .deny
                    )
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(theme.uiAccent.opacity(0.07), in: RoundedRectangle(cornerRadius: 9))
        .overlay {
            RoundedRectangle(cornerRadius: 9)
                .stroke(theme.uiAccent.opacity(0.20), lineWidth: 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func bridgeApprovalDecisionButton(
        title: String,
        systemImage: String,
        approval: ApprovalModalView.PendingApproval,
        decision: ApprovalModalView.Decision
    ) -> some View {
        Button {
            chatApprovalQueue.resolve(approval, decision: decision)
        } label: {
            Label(title, systemImage: systemImage)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 7)
                .padding(.vertical, 5)
                .background(theme.chatSurface.opacity(0.78), in: RoundedRectangle(cornerRadius: 7))
                .overlay {
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(theme.border.opacity(0.52), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .foregroundStyle(decision == .deny ? .red : theme.textPrimary)
    }

    private func bridgeApprovalDetail(_ approval: ApprovalModalView.PendingApproval) -> String {
        if let summary = approval.summary?.trimmingCharacters(in: .whitespacesAndNewlines),
           !summary.isEmpty {
            return clippedTranscriptText(summary)
        }
        return clippedTranscriptText(approval.argsJSON)
    }

    private func bridgeErrorTone(
        for kind: UserFacingChatErrorKind?
    ) -> (label: String, recoveryHint: String, systemImage: String, tint: Color) {
        switch kind ?? .generic {
        case .authFailure:
            return ("auth", "Open Settings to refresh provider credentials.", "key.fill", .orange)
        case .rateLimited:
            return ("rate limit", "Wait briefly or switch models from the picker.", "hourglass", .orange)
        case .providerUnreachable:
            return ("offline", "Check connectivity and retry this turn.", "wifi.exclamationmark", .orange)
        case .timedOut:
            return ("timeout", "Retry or choose a faster model.", "clock.badge.exclamationmark", .orange)
        case .contextOverflow:
            return ("context", "Start a fresh session or use a larger context model.", "rectangle.stack.badge.exclamationmark", .orange)
        case .modelNotReady:
            return ("model", "Open Settings or pick a ready model.", "cpu.fill", .orange)
        case .cancelled:
            return ("stopped", "The turn was stopped before completion.", "stop.circle.fill", theme.textSecondary)
        case .generic:
            return ("failure", "The agent surfaced this failure in the transcript.", "exclamationmark.triangle.fill", .red)
        }
    }

    @ViewBuilder
    private func bridgeTranscriptRow(_ message: ChatMessage) -> some View {
        if message.role == .user {
            bridgeUserTranscriptRow(message)
        } else if message.isError {
            bridgeErrorTranscriptRow(message)
        } else {
            bridgeAssistantTranscriptRow(message)
        }
    }

    private func bridgeUserTranscriptRow(_ message: ChatMessage) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Spacer(minLength: AgentFusionChatLayout.userBubbleLeadingReserve)
            TaggedMarkdownTextView(
                content: message.effectiveText,
                theme: theme,
                rippleStyle: .none,
                foregroundOverride: theme.userBubbleText,
                typographyRole: .user
            )
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(theme.userBubbleBg, in: RoundedRectangle(cornerRadius: 15))
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func bridgeAssistantTranscriptRow(_ message: ChatMessage) -> some View {
        let visibleText = UserFacingModelOutput.finalVisibleText(from: message.effectiveText)
        let failedToolResults = bridgeFailedToolResults(from: message.contentBlocks)

        return VStack(alignment: .leading, spacing: 10) {
            if !visibleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                AssistantResponseChrome {
                    TaggedMarkdownTextView(
                        content: visibleText,
                        theme: theme,
                        rippleStyle: .none,
                        foregroundOverride: theme.assistantBubbleForeground,
                        typographyRole: .assistant
                    )
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            ForEach(failedToolResults) { failure in
                bridgeToolFailureResultRow(failure)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func bridgeFailedToolResults(from blocks: [MessageContentBlock]?) -> [AgentFusionToolFailureSummary] {
        guard let blocks else { return [] }
        var toolNamesByID: [String: String] = [:]
        var failures: [AgentFusionToolFailureSummary] = []

        for block in blocks {
            switch block {
            case .toolUse(let id, let name, _):
                toolNamesByID[id] = name
            case .toolResult(let toolUseId, let content, let isError) where isError:
                let toolName = toolNamesByID[toolUseId] ?? toolUseId
                failures.append(AgentFusionToolFailureSummary(
                    id: toolUseId,
                    toolName: toolName,
                    summary: clippedTranscriptText(content)
                ))
            default:
                break
            }
        }

        return failures
    }

    private func bridgeToolFailureResultRow(_ failure: AgentFusionToolFailureSummary) -> some View {
        let surface = ToolActivityNarrator.surface(name: failure.toolName)
        let summary = failure.summary.isEmpty
            ? "Tool returned an error without details."
            : failure.summary

        return HStack(alignment: .top, spacing: 9) {
            Image(systemName: surface.symbolName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.red)
                .frame(width: 17, height: 17)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("tool failed")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.red.opacity(0.86))
                    Text(surface.badgeTitle.lowercased())
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(theme.textSecondary)
                }

                Text(summary)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.red)
                    .lineLimit(3)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 9))
        .overlay {
            RoundedRectangle(cornerRadius: 9)
                .stroke(.red.opacity(0.20), lineWidth: 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func bridgeErrorTranscriptRow(_ message: ChatMessage) -> some View {
        let errorTone = bridgeErrorTone(for: message.errorKind)

        HStack(alignment: .top, spacing: 8) {
            Image(systemName: errorTone.systemImage)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(errorTone.tint)
                .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: 3) {
                Text(errorTone.label)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(errorTone.tint.opacity(0.86))
                Text(errorTone.recoveryHint)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(2)
                Text(message.effectiveText)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(errorTone.tint)
                    .textSelection(.enabled)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(errorTone.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(errorTone.tint.opacity(0.20), lineWidth: 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func bridgeStreamingRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "waveform")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.uiAccent)
                .frame(width: 15, height: 15)

            VStack(alignment: .leading, spacing: 3) {
                Text("live")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(theme.textSecondary)
                Text(clippedTranscriptText(text))
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(3)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sessionRail(onHide: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            railHeader(title: context.appName, subtitle: bridgeEmptyLandingSubtitle, systemImage: "sidebar.left")

            VStack(alignment: .leading, spacing: 8) {
                railSectionTitle("Session")
                AgentFusionRailRow(title: "Current", detail: bridgeAgentStatusLabel, systemImage: bridgeAgentStatusSymbol)
                AgentFusionRailRow(title: "Mode", detail: context.modeLabel, systemImage: "switch.2")
                AgentFusionRailRow(title: "Surface", detail: context.presentation, systemImage: "macwindow")
                AgentFusionRailRow(title: "Portal", detail: context.portalContext.portal.label, systemImage: "rectangle.connected.to.line.below")
                AgentFusionRailRow(title: "Runtime", detail: "native agent", systemImage: "cpu")
            }
            .padding(12)

            if !agentChat.recentPortalSessions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    railSectionTitle("Recent")
                    ForEach(Array(agentChat.recentPortalSessions.prefix(6))) { summary in
                        Button {
                            activateRecentPortalSession(summary)
                            onHide()
                        } label: {
                            AgentFusionRecentSessionRow(
                                title: summary.title,
                                detail: recentPortalSessionDetail(summary),
                                meta: recentPortalSessionMeta(summary),
                                systemImage: recentPortalSessionSymbol(summary.portal),
                                isActive: summary.id == agentChat.activeSessionId
                            )
                        }
                        .buttonStyle(.plain)
                        .help("Activate portal context")
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }

            Spacer(minLength: 0)

            Button(action: onHide) {
                Label("Hide", systemImage: "sidebar.left")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.textSecondary)
            .padding(12)
        }
        .background(theme.chatSurface.opacity(0.94))
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(theme.border.opacity(0.72))
                .frame(width: 1)
        }
    }

    private func contextRail(onHide: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            railHeader(title: "Context", subtitle: context.portalContext.portal.label.lowercased(), systemImage: "sidebar.right")

            VStack(alignment: .leading, spacing: 8) {
                railSectionTitle("Grounding")
                AgentFusionRailRow(
                    title: "Model",
                    detail: context.modelVisibleSummary,
                    systemImage: "doc.text.magnifyingglass"
                )
                AgentFusionRailRow(title: "Vault", detail: clippedPath(context.vaultPath), systemImage: "books.vertical")
                AgentFusionRailRow(title: "Workspace", detail: clippedPath(context.workspacePath), systemImage: "folder")
                AgentFusionRailRow(title: "Session", detail: clippedSession(bridgeVisibleSessionId), systemImage: "number")
                AgentFusionRailRow(title: "Actions", detail: clippedActions(context.portalContext.approvedActions), systemImage: "checklist")
                AgentFusionRailRow(title: "Source", detail: "App context", systemImage: "point.3.connected.trianglepath.dotted")
            }
            .padding(12)

            if shouldShowBridgePortalContextSection {
                VStack(alignment: .leading, spacing: 8) {
                    railSectionTitle("Portal Context")
                    AgentFusionRailRow(
                        title: "Portal",
                        detail: bridgePortalContextSummary,
                        systemImage: recentPortalSessionSymbol(bridgeResolvedPortalContext.portal)
                    )
                    if let note = bridgeResolvedPortalContext.note {
                        AgentFusionRailRow(title: "Note", detail: bridgeNoteContextSummary(note), systemImage: "note.text")
                        AgentFusionRailRow(title: "Selection", detail: bridgeNoteSelectionSummary(note), systemImage: "text.quote")
                    }
                    if let graph = bridgeResolvedPortalContext.graph {
                        AgentFusionRailRow(title: "Graph", detail: bridgeGraphContextSummary(graph), systemImage: "point.3.connected.trianglepath.dotted")
                        AgentFusionRailRow(title: "Neighborhood", detail: bridgeGraphNeighborhoodSummary(graph), systemImage: "circle.hexagongrid")
                    }
                    if !bridgeResolvedPortalContext.additionalContextAttachments.isEmpty {
                        AgentFusionRailRow(title: "Attached", detail: bridgeAdditionalAttachmentSummary, systemImage: "paperclip")
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }

            if !bridgeActionDescriptors.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    railSectionTitle("Portal Actions")
                    ForEach(bridgeActionDescriptors, id: \.id) { action in
                        AgentFusionRailRow(
                            title: action.title,
                            detail: bridgeActionDescriptorDetail(action),
                            systemImage: bridgeActionSystemImage(action)
                        )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }

            VStack(alignment: .leading, spacing: 8) {
                railSectionTitle("Capabilities")
                AgentFusionRailRow(title: "Tools", detail: bridgeToolCapabilitySummary, systemImage: "wrench.and.screwdriver")
                AgentFusionRailRow(title: "Skills", detail: bridgeSkillCapabilitySummary, systemImage: "wand.and.stars")
                AgentFusionRailRow(title: "Commands", detail: bridgeCommandCapabilitySummary, systemImage: "command")
                AgentFusionRailRow(title: "MCP", detail: bridgeMCPCapabilitySummary, systemImage: "server.rack")
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)

            Button {
                appendBridgeAppContextSnapshotIntent()
                onHide()
            } label: {
                Label("Use Context", systemImage: "doc.badge.gearshape")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.textPrimary)
            .help("Insert app context snapshot")
            .padding(.horizontal, 12)
            .padding(.bottom, 12)

            Spacer(minLength: 0)

            Button(action: onHide) {
                Label("Hide", systemImage: "sidebar.right")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.textSecondary)
            .padding(12)
        }
        .background(theme.chatSurface.opacity(0.94))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(theme.border.opacity(0.72))
                .frame(width: 1)
        }
    }

    private func railControlButtons(compact: Bool) -> some View {
        HStack(spacing: 8) {
            railToggleButton(
                systemImage: "sidebar.left",
                isOn: compact ? showCompactSessionRail : showSessionRail
            ) {
                toggleSessionRail(compact: compact)
            }
            railToggleButton(
                systemImage: "sidebar.right",
                isOn: compact ? showCompactContextRail : showContextRail
            ) {
                toggleContextRail(compact: compact)
            }
        }
        .padding(6)
        .background(theme.chatSurface.opacity(0.72), in: RoundedRectangle(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(theme.border.opacity(0.72), lineWidth: 1)
        }
    }

    private func railHeader(title: String, subtitle: String, systemImage: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(theme.uiAccent)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(theme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 13)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(theme.border.opacity(0.6))
                .frame(height: 1)
        }
    }

    private func railSectionTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundStyle(theme.textSecondary)
            .padding(.bottom, 2)
    }

    private func railToggleButton(
        systemImage: String,
        isOn: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isOn ? theme.uiAccent : theme.textSecondary)
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(isOn ? "Hide panel" : "Show panel")
    }

    private func toggleContextRail(compact: Bool) {
        if compact {
            showCompactContextRail.toggle()
            if showCompactContextRail {
                showCompactSessionRail = false
            }
        } else {
            showContextRail.toggle()
        }
    }

    private func toggleSessionRail(compact: Bool) {
        if compact {
            showCompactSessionRail.toggle()
            if showCompactSessionRail {
                showCompactContextRail = false
            }
        } else {
            showSessionRail.toggle()
        }
    }

    private var canSubmitBridgePrompt: Bool {
        !bridgePromptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var bridgeSendButtonBackground: Color {
        canSubmitBridgePrompt ? theme.uiAccent : theme.card.opacity(0.72)
    }

    private var bridgeSelectedOperatingMode: EpistemosOperatingMode {
        MainChatOperatingModePreference.sanitize(
            EpistemosOperatingMode(rawValue: bridgeOperatingModeRaw) ?? .fast,
            for: inference
        )
    }

    private var bridgeOperatingModeBinding: Binding<EpistemosOperatingMode> {
        Binding(
            get: { bridgeSelectedOperatingMode },
            set: {
                bridgeOperatingModeRaw = MainChatOperatingModePreference.sanitize(
                    $0,
                    for: inference
                ).rawValue
            }
        )
    }

    private var bridgeRuntimeTierLabel: String {
        switch bridgeSelectedOperatingMode {
        case .fast:
            return "Fast"
        case .thinking:
            return "Think"
        case .pro:
            return "Code"
        case .agent:
            return "Act"
        }
    }

    private var bridgeResolvedPortalContext: AgentPortalContextSnapshot {
        agentChat.activePortalContext ?? context.portalContext
    }

    private var bridgeVisibleSessionId: String? {
        agentChat.activeSessionId ?? context.portalContext.sessionId
    }

    private var shouldShowBridgePortalContextSection: Bool {
        let portalContext = bridgeResolvedPortalContext
        return portalContext.portal != .main
            || portalContext.note != nil
            || portalContext.graph != nil
            || portalContext.promptPreview != nil
            || !portalContext.additionalContextAttachments.isEmpty
    }

    private var bridgePortalContextSummary: String {
        let portalContext = bridgeResolvedPortalContext
        var parts = [portalContext.portal.label]
        if let title = portalContext.title {
            parts.append(title)
        }
        if let promptPreview = portalContext.promptPreview {
            parts.append(clippedInline(promptPreview, limit: 72))
        }
        return parts.joined(separator: " | ")
    }

    private func bridgeNoteContextSummary(_ note: AgentPortalContextSnapshot.NoteContext) -> String {
        var parts = [note.title ?? note.pageId]
        if let path = note.path {
            parts.append(clippedPath(path))
        }
        if !note.tags.isEmpty {
            parts.append("tags: \(note.tags.prefix(3).joined(separator: ","))")
        }
        if !note.backlinks.isEmpty {
            parts.append("\(note.backlinks.count) backlinks")
        }
        return parts.joined(separator: " | ")
    }

    private func bridgeNoteSelectionSummary(_ note: AgentPortalContextSnapshot.NoteContext) -> String {
        if let selectedText = note.selectedText {
            return clippedInline(selectedText, limit: 120)
        }
        if let visibleExcerpt = note.visibleExcerpt {
            return clippedInline(visibleExcerpt, limit: 120)
        }
        return "none"
    }

    private func bridgeGraphContextSummary(_ graph: AgentPortalContextSnapshot.GraphContext) -> String {
        var parts: [String] = []
        if let route = graph.route {
            parts.append(route)
        }
        if !graph.selectedNodeIds.isEmpty {
            parts.append("\(graph.selectedNodeIds.count) nodes")
        }
        if !graph.selectedEdgeIds.isEmpty {
            parts.append("\(graph.selectedEdgeIds.count) edges")
        }
        return parts.isEmpty ? "canvas" : parts.joined(separator: " | ")
    }

    private func bridgeGraphNeighborhoodSummary(_ graph: AgentPortalContextSnapshot.GraphContext) -> String {
        guard let neighborhoodSummary = graph.neighborhoodSummary else { return "none" }
        return clippedInline(neighborhoodSummary, limit: 140)
    }

    private var bridgeAdditionalAttachmentSummary: String {
        let attachments = bridgeResolvedPortalContext.additionalContextAttachments
        guard !attachments.isEmpty else { return "none" }
        return attachments.map(\.title).prefix(4).joined(separator: ", ")
    }

    private var bridgeActionDescriptors: [AgentPortalContextSnapshot.ActionDescriptor] {
        Array(bridgeResolvedPortalContext.actionDescriptors.prefix(6))
    }

    private var bridgeApprovedActionChips: [String] {
        bridgeActionDescriptors.map(\.id)
    }

    private var bridgeAppContextSnapshotText: String {
        let portalContext = bridgeResolvedPortalContext
        var lines: [String] = [
            "portal: \(portalContext.portal.label)",
            "session: \(clippedSession(bridgeVisibleSessionId))",
            "model: \(clippedInline(context.modelVisibleSummary, limit: 120))",
            "vault: \(clippedPath(context.vaultPath))",
            "workspace: \(clippedPath(context.workspacePath))",
        ]

        if let title = portalContext.title?.trimmingCharacters(in: .whitespacesAndNewlines),
           !title.isEmpty {
            lines.append("title: \(clippedInline(title, limit: 80))")
        }

        if let note = portalContext.note {
            lines.append("note: \(clippedInline(note.title ?? note.pageId, limit: 80))")
            if let selectedText = note.selectedText?.trimmingCharacters(in: .whitespacesAndNewlines),
               !selectedText.isEmpty {
                lines.append("selection: \(clippedInline(selectedText, limit: 120))")
            } else if let excerpt = note.visibleExcerpt?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !excerpt.isEmpty {
                lines.append("excerpt: \(clippedInline(excerpt, limit: 120))")
            }
            if !note.tags.isEmpty {
                lines.append("tags: \(note.tags.prefix(4).joined(separator: ","))")
            }
        }

        if let graph = portalContext.graph {
            if let route = graph.route?.trimmingCharacters(in: .whitespacesAndNewlines),
               !route.isEmpty {
                lines.append("graph: \(clippedInline(route, limit: 80))")
            }
            if !graph.selectedNodeIds.isEmpty {
                lines.append("graph nodes: \(graph.selectedNodeIds.prefix(6).joined(separator: ","))")
            }
            if !graph.selectedEdgeIds.isEmpty {
                lines.append("graph edges: \(graph.selectedEdgeIds.prefix(6).joined(separator: ","))")
            }
            if let neighborhood = graph.neighborhoodSummary?.trimmingCharacters(in: .whitespacesAndNewlines),
               !neighborhood.isEmpty {
                lines.append("neighborhood: \(clippedInline(neighborhood, limit: 120))")
            }
        }

        if !portalContext.additionalContextAttachments.isEmpty {
            lines.append("attached: \(portalContext.additionalContextAttachments.map(\.title).prefix(6).joined(separator: ","))")
        }
        if !bridgeActionDescriptors.isEmpty {
            lines.append("approved actions: \(bridgeActionDescriptors.map(\.id).joined(separator: ","))")
            for action in bridgeActionDescriptors.prefix(4) {
                lines.append("action \(action.id): \(bridgeActionDescriptorDetail(action))")
            }
        }

        lines.append("tools: \(bridgeToolCapabilitySummary)")
        lines.append("skills: \(bridgeSkillCapabilitySummary)")
        lines.append("commands: \(bridgeCommandCapabilitySummary)")
        lines.append("mcp: \(bridgeMCPCapabilitySummary)")

        return lines.prefix(18).map { "- \($0)" }.joined(separator: "\n")
    }

    private func appendBridgeAppContextSnapshotIntent() {
        let prompt = "Use this Epistemos app context snapshot:\n\(bridgeAppContextSnapshotText)"
        let trimmed = bridgePromptText.trimmingCharacters(in: .whitespacesAndNewlines)
        bridgePromptText = trimmed.isEmpty ? prompt : "\(trimmed)\n\n\(prompt)"
        handleBridgePromptTextChange(bridgePromptText)
        bridgePromptFocused = true
    }

    private func appendBridgeActionIntent(_ action: AgentPortalContextSnapshot.ActionDescriptor) {
        let approval = action.requiresApproval ? " Request native approval before changing app state." : ""
        let prompt = "Use \(action.title) (\(action.id)) for this context.\(approval)"
        let trimmed = bridgePromptText.trimmingCharacters(in: .whitespacesAndNewlines)
        bridgePromptText = trimmed.isEmpty ? prompt : "\(trimmed) \(prompt)"
        handleBridgePromptTextChange(bridgePromptText)
        bridgePromptFocused = true
    }

    private func bridgeActionDescriptorDetail(_ action: AgentPortalContextSnapshot.ActionDescriptor) -> String {
        let approval = action.requiresApproval ? "approval required" : "no approval"
        let mutation = action.mutatesAppState ? "mutates app state" : "read-only"
        return "\(approval) | \(mutation) | \(clippedInline(action.summary, limit: 96))"
    }

    private func bridgeActionHelp(_ action: AgentPortalContextSnapshot.ActionDescriptor) -> String {
        "\(action.id): \(bridgeActionDescriptorDetail(action))"
    }

    private func bridgeActionChipFill(_ action: AgentPortalContextSnapshot.ActionDescriptor) -> Color {
        action.requiresApproval
            ? theme.textSecondary.opacity(0.10)
            : theme.uiAccent.opacity(0.08)
    }

    private func bridgeActionSystemImage(_ action: AgentPortalContextSnapshot.ActionDescriptor) -> String {
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

    private var bridgeToolCapabilitySummary: String {
        let available = agentCommandCenter.availableTools.count
        let enabled = agentCommandCenter.enabledToolNames.count
        guard available > 0 else {
            return enabled > 0 ? "\(enabled) enabled" : "none loaded"
        }
        return "\(enabled)/\(available) enabled"
    }

    private var bridgeSkillCapabilitySummary: String {
        capabilityCountLabel(agentCommandCenter.availableSkills.count, singular: "skill", plural: "skills")
    }

    private var bridgeCommandCapabilitySummary: String {
        capabilityCountLabel(supportedBridgeSlashCommands.count, singular: "command", plural: "commands")
    }

    private var bridgeMCPCapabilitySummary: String {
        let tools = agentCommandCenter.mcpToolCount
        let runs = agentCommandCenter.mcpExecutionCount
        guard tools > 0 else {
            return runs > 0 ? "\(runs) runs" : "ready"
        }
        return "\(tools) tools | \(runs) runs"
    }

    private var bridgeAgentClonePromptCapabilityLines: [String] {
        [
            "model: \(clippedInline(context.modelVisibleSummary, limit: 120))",
            "tools: \(bridgeToolCapabilitySummary)",
            "skills: \(bridgeSkillCapabilitySummary)",
            "commands: \(bridgeCommandCapabilitySummary)",
            "mcp: \(bridgeMCPCapabilitySummary)",
        ]
    }

    private func capabilityCountLabel(_ count: Int, singular: String, plural: String) -> String {
        count == 1 ? "1 \(singular)" : "\(count) \(plural)"
    }

    private var supportedBridgeOperatingModes: [EpistemosOperatingMode] {
        MainChatOperatingModePreference.supportedModes(for: inference)
    }

    private var supportedBridgeSlashCommands: [ACCSlashCommand] {
        ACCSlashCommand.availableCommands(for: supportedBridgeOperatingModes)
    }

    private var supportedBridgeSlashItems: [ComposerSlashCommandItem] {
        ComposerSlashCommandItem.all(
            commands: supportedBridgeSlashCommands,
            skills: agentCommandCenter.availableSkills
        )
    }

    private var filteredBridgeSlashItems: [ComposerSlashCommandItem] {
        SlashCommandPopover.filteredItems(
            items: supportedBridgeSlashItems,
            filter: bridgeSlashFilter
        )
    }

    private var highlightedBridgeSlashItem: ComposerSlashCommandItem? {
        filteredBridgeSlashItems.first
    }

    private var ambientManifest: VaultManifest? {
        vaultSync.ambientManifest ?? AppBootstrap.shared?.ambientManifest
    }

    private var bridgeMentionSearchResults: ComposerReferenceSearchResults {
        noteReferenceSearchResults(
            filter: bridgeMentionFilter,
            manifest: ambientManifest,
            indexedNoteIDs: bridgeReferenceSearch.indexedNoteIDs,
            indexedNoteSnippets: bridgeReferenceSearch.indexedNoteSnippetsByPageID
        )
    }

    private var bridgeMentionKeyboardChoices: [ComposerReferenceChoice] {
        ComposerReferenceKeyboardSelection.choices(
            from: bridgeMentionSearchResults,
            style: .mention
        )
    }

    private var bridgeAllNotesContextAttached: Bool {
        bridgeContextAttachments.contains { $0.kind == .allNotes }
    }

    private var bridgePortalContext: AgentPortalContextSnapshot {
        var portalContext = bridgeResolvedPortalContext.withAdditionalContextAttachments(bridgeContextAttachments)
        portalContext.promptPreview = bridgePromptText
        if let sessionId = bridgeVisibleSessionId {
            portalContext = portalContext.withSessionId(sessionId)
        }
        return portalContext
    }

    private func noteReferenceSearchResults(
        filter: String,
        manifest: VaultManifest?,
        indexedNoteIDs: [String],
        indexedNoteSnippets: [String: String]
    ) -> ComposerReferenceSearchResults {
        let query = filter.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let manifest else {
            return ComposerReferenceSearchResults(
                query: query,
                notes: [],
                vaultNoteCount: 0,
                indexedNoteSnippetsByPageID: indexedNoteSnippets
            )
        }

        let entriesByID = Dictionary(uniqueKeysWithValues: manifest.entries.map { ($0.pageId, $0) })
        let directMatches: [VaultManifest.ManifestEntry]
        if query.isEmpty {
            directMatches = Array(manifest.entries.sorted { lhs, rhs in
                lhs.updatedAt > rhs.updatedAt
            }.prefix(12))
        } else {
            let lowercaseQuery = query.lowercased()
            directMatches = manifest.entries.filter { entry in
                let haystack = [
                    entry.title,
                    entry.folderName ?? "",
                    entry.tags.joined(separator: " "),
                    entry.snippet,
                ].joined(separator: " ").lowercased()
                return haystack.contains(lowercaseQuery)
            }
        }

        var seen = Set<String>()
        var orderedEntries: [VaultManifest.ManifestEntry] = []
        for entry in indexedNoteIDs.compactMap({ entriesByID[$0] }) + directMatches {
            guard seen.insert(entry.pageId).inserted else { continue }
            orderedEntries.append(entry)
        }

        var notes: [NoteMentionChoice] = query.isEmpty ? [.allNotes] : []
        notes.append(contentsOf: orderedEntries.prefix(12).map(NoteMentionChoice.entry))
        return ComposerReferenceSearchResults(
            query: query,
            notes: notes,
            vaultNoteCount: manifest.totalNoteCount,
            indexedNoteSnippetsByPageID: indexedNoteSnippets
        )
    }

    private var recentBridgeMessages: [ChatMessage] {
        Array(agentChat.messages.suffix(4))
    }

    private func appendBridgeVoiceTranscript(_ transcript: String) {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if bridgePromptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            bridgePromptText = trimmed
        } else if bridgePromptText.last?.isWhitespace == true {
            bridgePromptText += trimmed
        } else {
            bridgePromptText += " " + trimmed
        }
        bridgePromptFocused = true
    }

    private func handleBridgePromptTextChange(_ newValue: String) {
        refreshBridgeSlashMenu(for: newValue)
        if let filter = ComposerReferenceHelpers.mentionFilter(in: newValue) {
            bridgeMentionFilter = filter
            showBridgeMentionDropdown = true
            updateBridgeReferenceSearch(filter: filter)
        } else {
            showBridgeMentionDropdown = false
            bridgeMentionFilter = ""
            bridgeReferenceSearch.reset()
        }
    }

    private func refreshBridgeSlashMenu(for newValue: String) {
        guard let filter = ComposerSlashMenuLogic.filter(in: newValue) else {
            if showBridgeSlashMenu {
                showBridgeSlashMenu = false
                bridgeSlashFilter = ""
            }
            return
        }
        bridgeSlashFilter = filter
        showBridgeSlashMenu = true
    }

    private func openBridgeSlashCommandMenu() {
        guard !supportedBridgeSlashItems.isEmpty else { return }
        bridgeSlashFilter = ""
        showBridgeSlashMenu = true
        bridgePromptFocused = true
    }

    private func applyBridgeSlashItem(_ item: ComposerSlashCommandItem) {
        if let command = item.command {
            bridgeOperatingModeRaw = MainChatOperatingModePreference.sanitize(
                command.defaultOperatingMode,
                for: inference,
                availableModes: supportedBridgeOperatingModes
            ).rawValue
            bridgePromptText = ComposerSlashMenuLogic.textAfterApplying(item, to: bridgePromptText)
            if bridgePromptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               let suggestedPrompt = item.suggestedPrompt {
                bridgePromptText = suggestedPrompt
            }
        } else {
            let remaining = ComposerSlashMenuLogic.textAfterApplying(item, to: bridgePromptText)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            bridgePromptText = remaining.isEmpty
                ? "/\(item.rawValue) "
                : "/\(item.rawValue) \(remaining)"
        }
        selectedBridgeSlashItem = item
        showBridgeSlashMenu = false
        bridgeSlashFilter = ""
        bridgePromptFocused = true
    }

    private func insertBridgeMentionToken() {
        if !bridgePromptText.hasSuffix("@") {
            if !bridgePromptText.isEmpty,
               bridgePromptText.last?.isWhitespace == false {
                bridgePromptText.append(" ")
            }
            bridgePromptText.append("@")
        }
        handleBridgePromptTextChange(bridgePromptText)
        bridgePromptFocused = true
    }

    private func updateBridgeReferenceSearch(filter: String) {
        bridgeReferenceSearch.update(
            filter: filter,
            manifest: ambientManifest,
            vaultSync: vaultSync
        )
    }

    private func attachBridgeMentionReference(_ choice: ComposerReferenceChoice) {
        let attachment = ComposerReferenceHelpers.contextAttachment(
            for: choice,
            vaultId: vaultSync.vaultURL?.lastPathComponent
        )
        if !bridgeContextAttachments.contains(attachment) {
            bridgeContextAttachments.append(attachment)
        }
        bridgePromptText = ComposerReferenceHelpers.removingTrailingMention(from: bridgePromptText)
        dismissBridgeReferencePopover()
        bridgePromptFocused = true
    }

    private func dismissBridgeReferencePopover() {
        showBridgeMentionDropdown = false
        bridgeMentionFilter = ""
        bridgeReferenceSearch.reset()
    }

    private func removeBridgeContextAttachment(_ id: String) {
        bridgeContextAttachments.removeAll { $0.id == id }
    }

    private func toggleBridgeAllNotesContext() {
        let attachment = ComposerReferenceHelpers.allNotesAttachment
        if bridgeAllNotesContextAttached {
            removeBridgeContextAttachment(attachment.id)
        } else if !bridgeContextAttachments.contains(attachment) {
            bridgeContextAttachments.append(attachment)
        }
        bridgePromptFocused = true
    }

    private func startNewBridgeSession() {
        bridgeContextAttachments = []
        selectedBridgeSlashItem = nil
        agentChat.startNewSession(portalContext: context.portalContext)
        syncBridgeHostContext()
        bridgePromptFocused = true
        showBridgeRuntimePicker = false
        showBridgeSlashMenu = false
        dismissBridgeReferencePopover()
        mirroredAgentCloneMessages = []
        mirrorTask?.cancel()
    }

    private func submitBridgePromptFromDock() {
        if showBridgeSlashMenu, let highlightedBridgeSlashItem {
            applyBridgeSlashItem(highlightedBridgeSlashItem)
            return
        }
        if showBridgeMentionDropdown, let choice = bridgeMentionKeyboardChoices.first {
            attachBridgeMentionReference(choice)
            return
        }

        let trimmed = bridgePromptText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let portalContext = bridgePortalContext

        if agentChat.activeSessionId == nil {
            agentChat.startNewSession(portalContext: portalContext)
        }
        agentChat.submitAgentQuery(trimmed, portalContext: portalContext)
        syncBridgeHostContext(portalContext: agentChat.activePortalContext ?? portalContext)
        startMirroringAgentCloneSession(after: Date().addingTimeInterval(-2))
        AgentCloneBridge.submitPrompt(portalContext.agentClonePromptEnvelope(
            userPrompt: trimmed,
            capabilityLines: bridgeAgentClonePromptCapabilityLines
        ))
        bridgePromptText = ""
        showBridgeRuntimePicker = false
        showBridgeSlashMenu = false
        dismissBridgeReferencePopover()
    }

    private func startMirroringAgentCloneSession(after startDate: Date) {
        mirrorTask?.cancel()
        mirroredAgentCloneMessages = []
        let appSupportPath = context.appSupportPath
        mirrorTask = Task { @MainActor in
            var lastSnapshot: [AgentCloneMirroredMessage] = []
            for _ in 0..<120 {
                if Task.isCancelled { return }
                let snapshot = await AgentCloneSessionMirror.snapshot(
                    appSupportPath: appSupportPath,
                    modifiedAfter: startDate
                )
                if snapshot != lastSnapshot {
                    lastSnapshot = snapshot
                    mirroredAgentCloneMessages = snapshot
                }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    private func syncBridgeHostContext(portalContext: AgentPortalContextSnapshot? = nil) {
        AgentCloneBridge.updateHostContext(AgentCloneHostContext(
            appName: context.appName,
            workspaceRootPath: context.workspacePath,
            vaultRootPath: context.vaultPath,
            appSupportRootPath: context.appSupportPath,
            mode: context.modeLabel,
            presentation: portalContext?.bridgePresentation
                ?? agentChat.activePortalContext?.bridgePresentation
                ?? context.bridgePresentation
        ))
    }

    private func activateRecentPortalSession(_ summary: AgentPortalSessionSummary) {
        bridgeContextAttachments = []
        selectedBridgeSlashItem = nil
        bridgePromptText = ""
        showBridgeRuntimePicker = false
        showBridgeSlashMenu = false
        dismissBridgeReferencePopover()
        mirroredAgentCloneMessages = []
        mirrorTask?.cancel()
        agentChat.activatePortalSession(summary)
        syncBridgeHostContext(portalContext: agentChat.activePortalContext ?? summary.portalContext)
        bridgePromptFocused = true
    }

    private func clippedPath(_ path: String?) -> String {
        guard let path, !path.isEmpty else { return "none" }
        let parts = path.split(separator: "/").map(String.init)
        guard parts.count > 2 else { return path }
        return ".../" + parts.suffix(2).joined(separator: "/")
    }

    private func clippedInline(_ value: String, limit: Int) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > limit else { return trimmed }
        return String(trimmed.prefix(max(0, limit - 3))) + "..."
    }

    private func clippedSession(_ sessionId: String?) -> String {
        guard let sessionId, !sessionId.isEmpty else { return "none" }
        return String(sessionId.prefix(8))
    }

    private func recentPortalSessionDetail(_ summary: AgentPortalSessionSummary) -> String {
        if let promptPreview = summary.promptPreview {
            return promptPreview
        }
        return summary.detail
    }

    private func recentPortalSessionMeta(_ summary: AgentPortalSessionSummary) -> String {
        [
            summary.portal.label,
            clippedSession(summary.id),
            recentPortalMessageCountLabel(summary.messageCount),
        ]
        .joined(separator: " | ")
    }

    private func recentPortalSessionContextLine(
        _ summary: AgentPortalSessionSummary,
        compact: Bool
    ) -> String {
        let portalContext = summary.portalContext
        var parts = [portalContext.portal.label]

        if let title = portalContext.title?.trimmingCharacters(in: .whitespacesAndNewlines),
           !title.isEmpty,
           title != portalContext.portal.label {
            parts.append(title)
        }

        if let note = portalContext.note {
            parts.append("note: \(note.title ?? note.pageId)")
            if let selectedText = note.selectedText?.trimmingCharacters(in: .whitespacesAndNewlines),
               !selectedText.isEmpty {
                parts.append("selection: \(clippedInline(selectedText, limit: compact ? 36 : 52))")
            } else if let excerpt = note.visibleExcerpt?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !excerpt.isEmpty {
                parts.append("excerpt: \(clippedInline(excerpt, limit: compact ? 36 : 52))")
            }
        }

        if let graph = portalContext.graph {
            if let route = graph.route?.trimmingCharacters(in: .whitespacesAndNewlines),
               !route.isEmpty {
                parts.append("graph: \(route)")
            }
            if !graph.selectedNodeIds.isEmpty {
                parts.append("\(graph.selectedNodeIds.count) nodes")
            }
            if !graph.selectedEdgeIds.isEmpty {
                parts.append("\(graph.selectedEdgeIds.count) edges")
            }
        }

        if !portalContext.additionalContextAttachments.isEmpty {
            let attached = portalContext.additionalContextAttachments
                .map(\.title)
                .prefix(compact ? 2 : 3)
                .joined(separator: ", ")
            parts.append("attached: \(attached)")
        }

        if !portalContext.approvedActions.isEmpty {
            parts.append("actions: \(portalContext.approvedActions.prefix(compact ? 2 : 3).joined(separator: ","))")
        }

        return clippedInline(parts.joined(separator: " | "), limit: compact ? 96 : 144)
    }

    private func recentPortalMessageCountLabel(_ count: Int) -> String {
        count == 1 ? "1 message" : "\(count) messages"
    }

    private func recentPortalSessionSymbol(_ portal: AgentPortalContextSnapshot.Portal) -> String {
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

    private func clippedActions(_ actions: [String]) -> String {
        guard !actions.isEmpty else { return "none" }
        return actions.prefix(3).joined(separator: ", ")
    }

    private func clippedTranscriptText(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 360 else { return trimmed }
        return String(trimmed.prefix(357)) + "..."
    }
}

private struct AgentFusionRecentSessionRow: View {
    let title: String
    let detail: String
    let meta: String
    let systemImage: String
    let isActive: Bool

    @Environment(UIState.self) private var ui
    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isActive ? theme.uiAccent : theme.textSecondary)
                .frame(width: 16, height: 16)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)
                    if isActive {
                        Text("active")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundStyle(theme.uiAccent)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(theme.uiAccent.opacity(0.10), in: Capsule())
                    }
                }

                Text(detail)
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(2)
                    .truncationMode(.middle)

                Text(meta)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(theme.textSecondary.opacity(0.78))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(
            isActive ? theme.uiAccent.opacity(0.08) : theme.chatSurface.opacity(0.42),
            in: RoundedRectangle(cornerRadius: 6)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(isActive ? theme.uiAccent.opacity(0.26) : theme.border.opacity(0.42), lineWidth: 1)
        }
    }
}

private struct AgentFusionRailRow: View {
    let title: String
    let detail: String
    let systemImage: String

    @Environment(UIState.self) private var ui
    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(theme.textSecondary)
                .frame(width: 16, height: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(theme.textPrimary)
                Text(detail)
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(theme.chatSurface.opacity(0.42), in: RoundedRectangle(cornerRadius: 5))
        .overlay {
            RoundedRectangle(cornerRadius: 5)
                .stroke(theme.border.opacity(0.42), lineWidth: 1)
        }
    }
}

private struct AgentFusionToolFailureSummary: Identifiable, Equatable, Sendable {
    let id: String
    let toolName: String
    let summary: String
}

private struct AgentCloneMirroredMessage: Identifiable, Equatable, Sendable {
    enum Role: String, Sendable {
        case assistant
        case tool
    }

    let id: String
    let role: Role
    let text: String
    let sourceSessionId: String
}

private enum AgentCloneSessionMirror {
    private static let maxMirroredFileBytes = 1_048_576

    static func snapshot(
        appSupportPath: String?,
        modifiedAfter startDate: Date
    ) async -> [AgentCloneMirroredMessage] {
        await Task.detached(priority: .utility) {
            snapshotSync(appSupportPath: appSupportPath, modifiedAfter: startDate)
        }.value
    }

    private static func snapshotSync(
        appSupportPath: String?,
        modifiedAfter startDate: Date
    ) -> [AgentCloneMirroredMessage] {
        guard let appSupportPath, !appSupportPath.isEmpty else { return [] }

        let sessionsURL = URL(fileURLWithPath: (appSupportPath as NSString).expandingTildeInPath, isDirectory: true)
            .appendingPathComponent("sessions", isDirectory: true)
        let fileManager = FileManager.default
        let resourceKeys: Set<URLResourceKey> = [.contentModificationDateKey, .fileSizeKey]
        let files = (try? fileManager.contentsOfDirectory(
            at: sessionsURL,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles]
        )) ?? []

        let candidates = files
            .filter { $0.pathExtension == "jsonl" }
            .compactMap { url -> (url: URL, modifiedAt: Date, byteCount: Int)? in
                guard let values = try? url.resourceValues(forKeys: resourceKeys),
                      let modifiedAt = values.contentModificationDate,
                      modifiedAt >= startDate else {
                    return nil
                }
                return (url, modifiedAt, values.fileSize ?? 0)
            }
            .filter { $0.byteCount <= maxMirroredFileBytes }
            .sorted { $0.modifiedAt > $1.modifiedAt }

        for candidate in candidates.prefix(3) {
            let messages = mirroredMessages(from: candidate.url)
            if !messages.isEmpty {
                return messages
            }
        }
        return []
    }

    private static func mirroredMessages(from url: URL) -> [AgentCloneMirroredMessage] {
        guard let contents = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        let sessionId = url.deletingPathExtension().lastPathComponent
        var messages: [AgentCloneMirroredMessage] = []

        for (lineIndex, line) in contents.split(separator: "\n").enumerated() {
            guard let data = String(line).data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let roleValue = object["role"] as? String else {
                continue
            }

            let role: AgentCloneMirroredMessage.Role
            switch roleValue {
            case "assistant":
                role = .assistant
            case "user":
                role = .tool
            default:
                continue
            }

            let text = mirroredText(from: object["content"], role: role)
            guard !text.isEmpty else { continue }

            messages.append(AgentCloneMirroredMessage(
                id: "\(sessionId)-\(lineIndex)-\(role.rawValue)",
                role: role,
                text: text,
                sourceSessionId: sessionId
            ))
        }

        return Array(messages.suffix(6))
    }

    private static func mirroredText(from content: Any?, role: AgentCloneMirroredMessage.Role) -> String {
        if let text = content as? String {
            return normalized(text)
        }

        guard let blocks = content as? [[String: Any]] else { return "" }
        var parts: [String] = []
        for block in blocks {
            if let text = block["text"] as? String {
                parts.append(text)
                continue
            }
            if role == .assistant,
               let name = block["name"] as? String,
               (block["type"] as? String) == "tool_use" {
                parts.append("tool \(name)")
                continue
            }
            if role == .tool,
               let toolUseId = block["tool_use_id"] as? String,
               let text = block["content"] as? String {
                parts.append("\(toolUseId): \(text)")
            }
        }

        return normalized(parts.joined(separator: "\n"))
    }

    private static func normalized(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 2_000 else { return trimmed }
        return String(trimmed.prefix(1_997)) + "..."
    }
}
#endif
