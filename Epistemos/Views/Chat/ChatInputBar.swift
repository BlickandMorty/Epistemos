import AppKit
import SwiftUI
import UniformTypeIdentifiers

enum MainChatComposerLayout {
    static let horizontalPadding: CGFloat = 11
    static let topPadding: CGFloat = 9
    static let bottomPadding: CGFloat = 7
    static let controlRowSpacing: CGFloat = 4
    static let controlRowTopPadding: CGFloat = 6
}

private struct ComposerPermissionGrantRow: Identifiable {
    let id: String
    let title: String
    let detail: String
    let systemImage: String
    let isRevocable: Bool
}


struct ComposerControlStrip<Content: View>: View {
    let spacing: CGFloat
    var resetKey: String = ""
    @ViewBuilder let content: () -> Content

    private let leadingAnchorID = "composer-control-strip-leading"

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: spacing) {
                    Color.clear
                        .frame(width: 1, height: 1)
                        .id(leadingAnchorID)
                    content()
                }
                .padding(.horizontal, 1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .onAppear {
                resetScrollPosition(using: proxy)
            }
            .onChange(of: resetKey) { _, _ in
                resetScrollPosition(using: proxy)
            }
        }
    }

    private func resetScrollPosition(using proxy: ScrollViewProxy) {
        Task { @MainActor in
            proxy.scrollTo(leadingAnchorID, anchor: .leading)
            await Task.yield()
            proxy.scrollTo(leadingAnchorID, anchor: .leading)
        }
    }
}

// MARK: - Chat Input Bar
// Bottom input bar for the conversation view.
// Uses a stacked native-style composer: multiline text area on the first row,
// controls on the second row, all inside a rounded-rect material surface.

struct ChatInputBar: View {
    let onSubmit: (String) -> Void
    let onStop: () -> Void
    let isProcessing: Bool
    var operatingMode: Binding<EpistemosOperatingMode>? = nil
    var availableOperatingModes: [EpistemosOperatingMode]? = nil

    @Environment(UIState.self) private var ui
    @Environment(ChatState.self) private var chat
    @Environment(InferenceState.self) private var inference
    @Environment(VaultSyncService.self) private var vaultSync
    @Environment(ContextualShadowsState.self) private var contextualShadows
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var text = ""
    @State private var isFocused = false
    @State private var composerHeight = ChatComposerInputMetrics.minHeight
    @State private var lastConsumedDraftRevision: UInt = 0

    // Patch 7 / AMBIENT_RECALL_WIRING_PLAN §5 — chat-side recall debounce.
    // Held inside a small reference box because @State on Task<Void, Never>
    // would force re-renders on every reassignment.
    @State private var recallDebounceBox = ChatRecallDebounceBox()

    // Notes Mode @-mention dropdown
    @State private var showMentionDropdown = false
    @State private var mentionFilter = ""
    @State private var mentionKeyboardIndex = 0
    @State private var mentionPickerAutofocus = false
    @State private var referencePopoverStyle: ComposerReferencePopoverStyle = .mention
    @State private var referenceSearch = ComposerReferenceSearchState()
    @State private var showPermissionGrantPopover = false

    /// Slash-command menu. Surfaces the ACCSlashCommand catalog — plan,
    /// notes, code, debug, research, etc. — the moment the user types
    /// `/` at the start of the composer. Preserves the shortcut users
    /// had in the pre-fuse Agent Command Center; wires it into the
    /// fused main chat composer so slash commands + skills keep working
    /// everywhere.
    @State private var showSlashMenu = false
    @State private var slashFilter = ""
    @State private var slashKeyboardIndex = 0
    @State private var selectedSlashCommand: ACCSlashCommand?

    private var theme: EpistemosTheme { ui.theme }
    private var trimmedText: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedMentionFilter: String {
        mentionFilter.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private var ambientManifest: VaultManifest? {
        vaultSync.ambientManifest ?? AppBootstrap.shared?.ambientManifest
    }
    private let composerMetrics = AssistantComposerMetrics.mainChat
    private let placeholderText = ComposerAttachmentEntryHints.mainChatPlaceholder + "  Auto-routes when your prompt needs tools or a longer run."

    /// Capability the pill should display right now. During a streaming /
    /// agent turn, chat.currentCapability (set by ChatCoordinator from live
    /// delegate signals) wins — the user sees what's actually happening.
    /// When idle and the composer is non-empty, we run the pre-submit
    /// intent classifier on the draft text so the pill previews where
    /// the turn is about to go. Empty composer falls back to the live
    /// capability so cold state reads correctly.
    private var effectiveCapability: ChatCapability {
        if chat.isAgentExecuting || isProcessing {
            return chat.currentCapability
        }
        let trimmed = trimmedText
        guard !trimmed.isEmpty else {
            return chat.currentCapability
        }
        return ChatCapability.predictIntent(
            text: trimmed,
            isCloudProvider: isCloudSelection
        ).predicted
    }

    /// Whether the user has explicitly selected a cloud model. Derives from
    /// preferredChatModelSelection (the next-turn target), NOT the cloud
    /// provider preference — a user who keeps OpenAI in activeAIProvider
    /// but picks Bonsai in the chat picker is on LOCAL for the next turn.
    private var isCloudSelection: Bool {
        switch inference.preferredChatModelSelection {
        case .cloud: true
        case .localMLX, .appleIntelligence: false
        }
    }

    private var selectedRuntimeReady: Bool {
        guard let selectedMode = operatingMode?.wrappedValue else { return true }
        return inference.isChatSurfaceRuntimeReady(for: selectedMode)
    }

    /// Live-detail sub-signal shown in the pill while the agent is
    /// mid-tool-call. Turns the raw tool name + JSON input into a human
    /// phrase ("Searching the web for "quantum decoherence"") via
    /// ToolActivityNarrator so the composer reads as live activity
    /// instead of showing a bare identifier like "web_search". The
    /// narrator always returns *something* for a non-empty tool name so
    /// the pill isn't blank during the seconds the tool is running.
    private var pillDetail: String? {
        guard chat.isAgentExecuting else { return nil }
        guard let activeTool = chat.activeToolName, !activeTool.isEmpty else {
            return nil
        }
        return ToolActivityNarrator.phrase(
            name: activeTool,
            inputJson: chat.activeToolInputJson
        )
    }

    /// True when the composer draft looks like agent-tier work (creating /
    /// editing / deleting / installing / automating) BUT the user is on a
    /// local model — agent tier is cloud-only per CLAUDE.md, so the UI
    /// surfaces an honest nudge instead of silently downgrading.
    private var pillNeedsCloudWarning: Bool {
        guard !chat.isAgentExecuting, !isProcessing else { return false }
        let trimmed = trimmedText
        guard !trimmed.isEmpty else { return false }
        return ChatCapability.predictIntent(
            text: trimmed,
            isCloudProvider: isCloudSelection
        ).needsCloud
    }

    /// Inline nudge shown when the classifier predicts agent-tier work but
    /// the user is on a local model. Tapping the banner promotes the user
    /// to OpenAI (our default cloud provider) via
    /// InferenceState.setActiveAIProvider; ChatView's onChange hook will
    /// pick up the provider flip and refresh the pill automatically.
    /// Inspect the current composer text and show / hide / filter the
    /// slash-command menu accordingly. Menu opens when the user types `/`
    /// at the very start of the composer (or after whitespace at the
    /// start). Closes once `/` is deleted or the user commits an input.
    /// Append a fresh voice transcript to the composer draft, adding a
    /// single separator space when the existing draft doesn't already
    /// end in whitespace. Preserves whatever the user had already
    /// typed — dictation never clobbers a draft.
    private func insertVoiceTranscript(_ transcript: String) {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if text.isEmpty {
            text = trimmed
        } else if text.last?.isWhitespace == true {
            text.append(trimmed)
        } else {
            text.append(" \(trimmed)")
        }
    }

    private func refreshSlashMenu(for newValue: String) {
        let trimmedLeading = newValue.drop(while: \.isWhitespace)
        guard trimmedLeading.first == "/" else {
            if showSlashMenu {
                showSlashMenu = false
                slashFilter = ""
                slashKeyboardIndex = 0
            }
            return
        }
        let afterSlash = String(trimmedLeading.dropFirst())
        if !afterSlash.isEmpty {
            selectedSlashCommand = nil
        }
        // Close the menu as soon as the user adds whitespace — the
        // intent has become a free-form prompt that happens to start
        // with /something.
        if afterSlash.contains(where: { $0.isWhitespace || $0.isNewline }) {
            showSlashMenu = false
            slashFilter = ""
            slashKeyboardIndex = 0
            return
        }
        slashFilter = afterSlash
        slashKeyboardIndex = 0
        showSlashMenu = true
    }

    /// Apply the selected slash command: promote the operating mode to
    /// the command's default, strip the `/name` prefix from the
    /// composer, leaving a clean ready-to-type prompt, and optionally
    /// prefill with the command's suggested opener.
    private func applySlashCommand(_ command: ACCSlashCommand) {
        if let operatingMode {
            operatingMode.wrappedValue = MainChatOperatingModePreference.sanitize(
                command.defaultOperatingMode,
                for: inference,
                availableModes: availableOperatingModes
            )
        }
        selectedSlashCommand = command

        // Trim the leading `/token` plus any single trailing space so
        // the user can start typing immediately. If the user had already
        // typed additional text after the slash (unlikely given the
        // menu closes on whitespace, but safe), preserve it.
        let leadingWhitespace = text.prefix { $0.isWhitespace }
        let afterLeading = text.dropFirst(leadingWhitespace.count)
        if afterLeading.hasPrefix("/") {
            let slug = "/" + command.rawValue
            if afterLeading.hasPrefix(slug) {
                let suffix = afterLeading.dropFirst(slug.count)
                text = String(leadingWhitespace) + suffix
            } else {
                // Partial token — replace everything up to the next
                // whitespace with an empty string.
                let afterSlash = afterLeading.dropFirst()
                let partialEnd = afterSlash.firstIndex(where: { $0.isWhitespace }) ?? afterSlash.endIndex
                let remainder = afterSlash[partialEnd...]
                text = String(leadingWhitespace) + String(remainder)
            }
        }

        if trimmedText.isEmpty {
            text = command.suggestedPrompt
        }

        showSlashMenu = false
        slashFilter = ""
        slashKeyboardIndex = 0
    }

    private func openSlashCommandMenu() {
        guard !supportedSlashCommands.isEmpty else { return }
        slashFilter = ""
        slashKeyboardIndex = 0
        showSlashMenu = true
        isFocused = true
    }

    private func handleComposerCommand(_ selector: Selector, modifierFlags: NSEvent.ModifierFlags) -> Bool {
        guard let command = ChatComposerKeyHandling.overlayCommand(
            for: selector,
            modifierFlags: modifierFlags
        ) else {
            return false
        }

        if showMentionDropdown {
            return handleMentionOverlayCommand(command)
        }
        if showSlashMenu {
            return handleSlashOverlayCommand(command)
        }
        return false
    }

    private func handleMentionOverlayCommand(_ command: ChatComposerOverlayCommand) -> Bool {
        let choices = mentionKeyboardChoices
        switch command {
        case .moveDown:
            guard !choices.isEmpty else { return true }
            mentionKeyboardIndex = clamped(mentionKeyboardIndex + 1, count: choices.count)
            return true
        case .moveUp:
            guard !choices.isEmpty else { return true }
            mentionKeyboardIndex = clamped(mentionKeyboardIndex - 1, count: choices.count)
            return true
        case .confirm:
            guard !choices.isEmpty else { return true }
            attachMentionReference(choices[clamped(mentionKeyboardIndex, count: choices.count)])
            return true
        case .cancel:
            dismissReferencePopover()
            return true
        }
    }

    private func handleSlashOverlayCommand(_ command: ChatComposerOverlayCommand) -> Bool {
        let commands = filteredSlashCommands
        switch command {
        case .moveDown:
            guard !commands.isEmpty else { return true }
            slashKeyboardIndex = clamped(slashKeyboardIndex + 1, count: commands.count)
            return true
        case .moveUp:
            guard !commands.isEmpty else { return true }
            slashKeyboardIndex = clamped(slashKeyboardIndex - 1, count: commands.count)
            return true
        case .confirm:
            guard !commands.isEmpty else { return true }
            applySlashCommand(commands[clamped(slashKeyboardIndex, count: commands.count)])
            return true
        case .cancel:
            showSlashMenu = false
            slashFilter = ""
            slashKeyboardIndex = 0
            return true
        }
    }

    private func clamped(_ index: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return min(max(index, 0), count - 1)
    }

    private var needsCloudBanner: some View {
        Button {
            inference.setActiveAIProvider(.openAI)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "cloud.bolt.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.orange)
                Text("This needs tools. Tap to switch to OpenAI and keep it in the main chat.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.orange.opacity(0.7))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.25), lineWidth: 0.75)
        )
        .padding(.top, 6)
        .accessibilityLabel(
            "Switch to OpenAI and keep this in the main chat with tools. This prompt needs tools but a local model is selected."
        )
        .accessibilityAddTraits(.isButton)
    }
    private var composerAccentColor: Color { theme.resolved.accent.color }
    private var incognitoBinding: Binding<Bool> {
        Binding(
            get: { chat.isIncognito },
            set: { chat.isIncognito = $0 }
        )
    }
    private var mentionSearchResults: ChatCoordinator.ReferenceSearchResults {
        guard showMentionDropdown else {
            return ChatCoordinator.ReferenceSearchResults(
                notes: [], chats: [], vaultTitle: nil, vaultNoteCount: 0,
                isInventoryComplete: true, query: "", indexedMatchedNoteIDs: [],
                indexedNoteSnippetsByPageID: [:]
            )
        }
        return ChatCoordinator.searchReferenceResults(
            filter: trimmedMentionFilter,
            manifest: ambientManifest,
            chats: recentChats(),
            threads: AppBootstrap.shared?.threadState.chatThreads ?? [],
            indexedNoteIDs: referenceSearch.indexedNoteIDs,
            indexedNoteSnippets: referenceSearch.indexedNoteSnippetsByPageID
        )
    }
    private var mentionKeyboardChoices: [ComposerReferenceChoice] {
        ComposerReferenceKeyboardSelection.choices(
            from: mentionSearchResults,
            style: referencePopoverStyle
        )
    }
    private var composerControlResetKey: String {
        let supportedModes = MainChatOperatingModePreference.supportedModes(
            for: inference,
            availableModes: availableOperatingModes
        )
        return supportedModes.map(\.rawValue).joined(separator: "|")
            + "::"
            + inference.activeChatModelDisplayName
    }
    private var selectedOperatingMode: EpistemosOperatingMode {
        operatingMode?.wrappedValue ?? .fast
    }
    private var supportedSlashCommands: [ACCSlashCommand] {
        ACCSlashCommand.availableCommands(
            for: MainChatOperatingModePreference.supportedModes(
                for: inference,
                availableModes: availableOperatingModes
            )
        )
    }
    private var activeSelectedSlashCommand: ACCSlashCommand? {
        guard let selectedSlashCommand,
              supportedSlashCommands.contains(selectedSlashCommand) else {
            return nil
        }
        return selectedSlashCommand
    }
    private var filteredSlashCommands: [ACCSlashCommand] {
        SlashCommandPopover.filteredCommands(
            commands: supportedSlashCommands,
            filter: slashFilter
        )
    }
    private var highlightedSlashCommand: ACCSlashCommand? {
        guard !filteredSlashCommands.isEmpty else { return nil }
        return filteredSlashCommands[clamped(slashKeyboardIndex, count: filteredSlashCommands.count)]
    }
    private var composerIsActive: Bool {
        isFocused || !trimmedText.isEmpty || isProcessing || !chat.pendingAttachments.isEmpty || !chat.pendingContextAttachments.isEmpty
    }
    private var composerStatusPhase: AssistantComposerStatusPhase {
        AssistantComposerStatusPhase.resolve(
            isActive: isProcessing,
            streamingText: chat.streamingText
        )
    }
    private var composerStatusLabelState: AssistantComposerStatusLabelState? {
        AssistantComposerStatusLabelState.resolve(
            inputText: text,
            phase: composerStatusPhase,
            idleText: placeholderText,
            showsIdleLabel: false
        )
    }
    private var composerTextAreaHeight: CGFloat {
        max(ChatComposerInputMetrics.minHeight, composerHeight)
    }
    private var permissionGrantRows: [ComposerPermissionGrantRow] {
        var rows: [ComposerPermissionGrantRow] = []

        if let vaultURL = vaultSync.vaultURL {
            rows.append(
                ComposerPermissionGrantRow(
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
                ComposerPermissionGrantRow(
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
                ComposerPermissionGrantRow(
                    id: "file:\(attachment.id)",
                    title: attachment.name,
                    detail: "Read attached file",
                    systemImage: iconForType(attachment.type),
                    isRevocable: true
                )
            }
        )

        #if !EPISTEMOS_APP_STORE
        rows.append(
            ComposerPermissionGrantRow(
                id: "shell-approval",
                title: "Shell / external tools",
                detail: "Ask first for destructive or external work",
                systemImage: "terminal",
                isRevocable: false
            )
        )
        #endif

        return rows
    }
    private var permissionSummaryText: String {
        var segments: [String] = []
        if chat.pendingContextAttachments.contains(where: { $0.kind == .note || $0.kind == .folder }) {
            segments.append("Read + Edit attached notes")
        } else if !chat.pendingAttachments.isEmpty {
            segments.append("Read attached files")
        }
        if vaultSync.vaultURL != nil {
            segments.append("Read + Search vault")
        }
        #if !EPISTEMOS_APP_STORE
        segments.append("Shell: ask first")
        #endif
        if segments.isEmpty {
            segments.append("Local chat")
        }
        return segments.joined(separator: " · ")
    }
    var body: some View {
        VStack(spacing: 0) {
            // Sticky plan card (rendered when the agent has published a
            // todo list via the Rust `todo_write` tool). Sits above the
            // thin context bar so the user sees the current plan
            // glance-first; items flip live as the agent progresses.
            if let todos = chat.currentTodos, !todos.isEmpty {
                TodoSnapshotCard(snapshot: todos)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 6)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            // Context window usage indicator
            if chat.hasMessages {
                ContextWindowIndicator(
                    usageFraction: chat.contextUsageFraction,
                    usedTokens: chat.estimatedContextTokens,
                    maxTokens: chat.maxContextTokens
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 4)
            }

            // Pending attachments preview — collapsed to 0 height when empty
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(chat.pendingContextAttachments) { attachment in
                        HStack(spacing: 4) {
                            Image(systemName: attachment.systemImageName)
                                .font(.epSmall)
                            Text(attachment.title)
                                .font(.epSmall)
                                .lineLimit(1)
                            Button {
                                chat.removeContextAttachment(attachment.id)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.epSmall)
                                    .foregroundStyle(theme.mutedForeground.opacity(0.5))
                            }
                            .buttonStyle(NativeToolbarButtonStyle())
                            .accessibilityLabel("Remove context attachment")
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(theme.mutedForeground.opacity(0.08), in: Capsule())
                        .foregroundStyle(theme.mutedForeground.opacity(0.7))
                    }

                    ForEach(chat.pendingAttachments) { att in
                        let isSupported = inference.chatSurfaceSupportedFileTypes(
                            for: selectedOperatingMode
                        ).contains(att.type)
                        HStack(spacing: 4) {
                            if !isSupported {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.orange)
                            }
                            Image(systemName: iconForType(att.type))
                                .font(.epSmall)
                            Text(att.name)
                                .font(.epSmall)
                                .lineLimit(1)
                            Button {
                                chat.removeAttachment(att.id)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.epSmall)
                                    .foregroundStyle(theme.mutedForeground.opacity(0.5))
                            }
                            .buttonStyle(NativeToolbarButtonStyle())
                            .accessibilityLabel("Remove attachment")
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            (isSupported ? theme.mutedForeground.opacity(0.08) : Color.orange.opacity(0.1)),
                            in: Capsule()
                        )
                        .foregroundStyle(isSupported ? theme.mutedForeground.opacity(0.7) : .orange)
                        .help(isSupported ? att.name : "Current model doesn't support \(att.type.rawValue) files")
                    }
                }
                .padding(.horizontal, MainChatComposerLayout.horizontalPadding)
                .padding(.top, 6)
                .padding(.bottom, 4)
            }
            .frame(height: (chat.pendingAttachments.isEmpty && chat.pendingContextAttachments.isEmpty) ? 0 : nil)
            .clipped()
            .animation(reduceMotion ? nil : Motion.quick, value: chat.pendingAttachments.count + chat.pendingContextAttachments.count)

            // Image attachment warning for text-only models
            if chat.pendingAttachments.contains(where: { $0.type == .image }),
               !inference.chatSurfaceSupportsVision(for: selectedOperatingMode) {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                    Text("Current model doesn't support images. Switch to a vision-capable local model or a cloud vision model.")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .padding(.horizontal, MainChatComposerLayout.horizontalPadding)
                .padding(.bottom, 4)
            }

            permissionVisibilityChip
                .padding(.horizontal, MainChatComposerLayout.horizontalPadding)
                .padding(.bottom, 4)

            VStack(alignment: .leading, spacing: 0) {
                if chat.isIncognito {
                    temporaryChatBanner
                        .padding(.bottom, 8)
                }

                composerTextArea
                    .onChange(of: text) { _, newValue in
                        refreshSlashMenu(for: newValue)
                        scheduleContextualShadowsRecall(for: newValue)
                    }
                    .popover(isPresented: $showSlashMenu, arrowEdge: .top) {
                        SlashCommandPopover(
                            commands: supportedSlashCommands,
                            filter: slashFilter,
                            selectedCommand: highlightedSlashCommand,
                            onSelect: { command in
                                applySlashCommand(command)
                            }
                        )
                    }

                if pillNeedsCloudWarning {
                    needsCloudBanner
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                HStack(alignment: .center, spacing: MainChatComposerLayout.controlRowSpacing) {
                    ComposerControlStrip(spacing: 8, resetKey: composerControlResetKey) {
                        if !supportedSlashCommands.isEmpty {
                            slashButton
                        }
                        if let selectedSlashCommand = activeSelectedSlashCommand {
                            selectedSlashPill(for: selectedSlashCommand)
                        }
                        ChatBrainPickerMenu(
                            operatingMode: operatingMode,
                            availableOperatingModes: availableOperatingModes,
                            isTemporaryChatEnabled: incognitoBinding,
                            preferSplitToolbarControls: true
                        )
                        attachButton
                        ComposerMicButton { transcript in
                            insertVoiceTranscript(transcript)
                        }
                    }

                    Spacer(minLength: 4)

                    // Compact context-usage badge: visible any time the
                    // chat has messages OR the user has attached context,
                    // so pending attachments (which the full-bar hides
                    // behind a hover) still produce a visible number.
                    // The thin bar above the input continues to show a
                    // fill — this badge is the concrete "x / y (z%)"
                    // readout the user asked for when they noticed
                    // attachments weren't budging the meter.
                    if chat.hasMessages
                        || !chat.pendingAttachments.isEmpty
                        || !chat.pendingContextAttachments.isEmpty {
                        ContextWindowCompactBadge(
                            usageFraction: chat.contextUsageFraction,
                            usedTokens: chat.estimatedContextTokens,
                            maxTokens: chat.maxContextTokens
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.92)))
                    }

                    // Single source of truth for "what mode is the chat in."
                    // Pre-submit: ChatCapability.predictIntent scans the
                    // composer text and lights up the pill the moment the
                    // user's intent is obvious — .agent for tool-use verbs,
                    // .research for external-info prompts, etc. During a
                    // turn: chat.currentCapability is set by ChatCoordinator
                    // from the live streaming signals (takes precedence).
                    ChatCapabilityPill(
                        capability: effectiveCapability,
                        detail: pillDetail
                    )

                    // R2 wire-up — Apple-native STT (W10.11
                    // SpeechAnalyzer on macOS 26). Drop-in dictation
                    // affordance lives next to the capability pill,
                    // BEFORE the send button. Live partial → appended
                    // to text; final → committed + composer ready
                    // for Send. Honours the W11.4
                    // `dictationAutoStop` preference (auto =
                    // 2s-silence stop; manual = explicit Stop tap).
                    if #available(macOS 26.0, *) {
                        VoiceInputButton(
                            style: .iconWithPulse,
                            autoStopOnSilence: VoicePreferences.shared
                                .dictationAutoStop == .auto,
                            onPartial: { partial in
                                // Append the partial to the composer
                                // so the user sees the live transcript
                                // while they speak. Replaced on every
                                // partial (volatile range semantics).
                                text = partial
                            },
                            onFinal: { final in
                                text = final
                            }
                        )
                    }

                    ContextualShadowsButton()

                    sendButton
                }
                .padding(.top, MainChatComposerLayout.controlRowTopPadding)
            }
            .padding(.horizontal, MainChatComposerLayout.horizontalPadding)
            .padding(.top, MainChatComposerLayout.topPadding)
            .padding(.bottom, MainChatComposerLayout.bottomPadding)
        }
        .assistantComposerChrome(
            theme: theme,
            metrics: composerMetrics,
            isActive: composerIsActive,
            lightModeSurfaceTint: theme.resolved.background.color
        )
        .overlay(alignment: .topLeading) {
            if showMentionDropdown {
                ComposerReferencePopover(
                    isPresented: $showMentionDropdown,
                    results: mentionSearchResults,
                    query: $mentionFilter,
                    manifest: ambientManifest,
                    modelContext: modelContext,
                    idealWidth: referencePopoverStyle.idealWidth,
                    maxHeight: referencePopoverStyle.maxHeight,
                    style: referencePopoverStyle,
                    autofocusSearchField: mentionPickerAutofocus,
                    onDismiss: dismissReferencePopover,
                    onSelect: attachMentionReference
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            ContextualShadowsPanel(onOpen: openContextualShadowHit)
                .padding(.trailing, 12)
                .padding(.bottom, 48)
        }
        .padding(.horizontal, ChatLayout.mainComposerHorizontalPadding)
        .padding(.bottom, Spacing.md)
        .frame(maxWidth: ChatLayout.mainComposerMaxWidth)
        .frame(maxWidth: .infinity)
        .onAppear {
            applyPendingComposerDraftIfNeeded()
        }
        .onChange(of: chat.pendingComposerDraftRevision) { _, _ in
            applyPendingComposerDraftIfNeeded()
        }
    }

    private var permissionVisibilityChip: some View {
        Button {
            showPermissionGrantPopover.toggle()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.resolved.accent.color)
                Text(permissionSummaryText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(theme.textTertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(theme.mutedForeground.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(theme.border.opacity(0.45), lineWidth: 0.7)
            )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showPermissionGrantPopover, arrowEdge: .top) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Current Access")
                    .font(.headline)

                Text("Removing an attachment revokes the corresponding attached-resource access immediately for this composer.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(permissionGrantRows) { row in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: row.systemImage)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(theme.resolved.accent.color)
                                .frame(width: 16, alignment: .center)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.title)
                                    .font(.system(size: 12, weight: .semibold))
                                Text(row.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer(minLength: 8)

                            if row.isRevocable {
                                Button("Revoke") {
                                    revokePermissionGrant(row.id)
                                }
                                .buttonStyle(.borderless)
                                .font(.caption.weight(.semibold))
                            }
                        }

                        if row.id != permissionGrantRows.last?.id {
                            Divider()
                        }
                    }
                }
            }
            .padding(14)
            .frame(width: 360, alignment: .leading)
        }
        .accessibilityLabel("Current assistant access")
        #if EPISTEMOS_APP_STORE
        .accessibilityHint("Shows attached-resource and vault access for this chat.")
        #else
        .accessibilityHint("Shows attached-resource, vault, and shell approval access for this chat.")
        #endif
    }

    private var composerTextArea: some View {
        ChatComposerTextEditor(
            text: $text,
            height: $composerHeight,
            isFocused: $isFocused,
            theme: theme,
            isProcessing: isProcessing,
            onCommand: { selector, modifierFlags in
                handleComposerCommand(selector, modifierFlags: modifierFlags)
            }
        ) {
            submitCurrentText()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: composerHeight)
        .accessibilityLabel("Message input")
        .accessibilityHint(
            isProcessing
                ? "You can keep typing while the current response finishes. Press stop to cancel."
                : "Type a question or command. Press Shift-Enter for a new line."
        )
        .overlay(alignment: .topLeading) {
            if let labelState = composerStatusLabelState {
                AssistantAnimatedStatusLabel(
                    state: labelState,
                    phase: composerStatusPhase,
                    theme: theme,
                    font: .system(size: 16, weight: .regular, design: .rounded),
                    activeFont: .custom(AppDisplayTypography.displayFontName, size: 12)
                )
                .padding(.top, ChatComposerInputMetrics.placeholderTopPadding)
                .padding(.leading, ChatComposerInputMetrics.horizontalInset)
            }
        }
        .overlay(alignment: .topLeading) {
            if text.isEmpty && composerStatusLabelState == nil {
                Text(placeholderText)
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundStyle(theme.mutedForeground.opacity(0.55))
                    .padding(.top, ChatComposerInputMetrics.placeholderTopPadding)
                    .padding(.leading, ChatComposerInputMetrics.horizontalInset)
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: composerTextAreaHeight, alignment: .topLeading)
        .onChange(of: text) { _, newVal in
            if let filter = ComposerReferenceHelpers.mentionFilter(in: newVal) {
                referencePopoverStyle = .mention
                mentionFilter = filter
                mentionKeyboardIndex = 0
                mentionPickerAutofocus = false
                if !showMentionDropdown { showMentionDropdown = true }
            } else if showMentionDropdown {
                showMentionDropdown = false
                referencePopoverStyle = .mention
                mentionKeyboardIndex = 0
                mentionPickerAutofocus = false
                referenceSearch.reset()
            }
        }
        .onChange(of: mentionFilter) { _, newValue in
            updateMentionReferenceSearch(filter: newValue)
        }
    }

    private var attachButton: some View {
        ToolbarCapsuleButton(
            title: nil,
            systemImage: "plus",
            variant: .toolbar,
            helpText: "Attach File",
            accessibilityLabel: "Attach file"
        ) {
            openFilePicker()
        }
        .accessibilityHint("Open file picker to attach a document")
        .disabled(isProcessing)
    }

    private var slashButton: some View {
        ToolbarCapsuleButton(
            title: "/",
            systemImage: "command",
            variant: .toolbar,
            helpText: "Commands",
            accessibilityLabel: "Open commands"
        ) {
            openSlashCommandMenu()
        }
        .accessibilityHint("Open the slash command menu")
        .disabled(isProcessing)
    }

    private func selectedSlashPill(for command: ACCSlashCommand) -> some View {
        ToolbarCapsuleButton(
            title: "/\(command.rawValue)",
            systemImage: command.icon,
            variant: .toolbar,
            helpText: command.helpText,
            accessibilityLabel: "Selected command \(command.displayName)"
        ) {
            selectedSlashCommand = nil
        }
        .accessibilityHint("Clear the selected slash command")
        .disabled(isProcessing)
    }

    private var temporaryChatBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "eye.slash.fill")
                .font(.system(size: 11, weight: .semibold))
            VStack(alignment: .leading, spacing: 1) {
                Text("Temporary Chat")
                    .font(.system(size: 11, weight: .semibold))
                Text("Messages stay in memory only and will not be saved.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(theme.textTertiary)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(theme.resolved.accent.color)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(theme.resolved.accent.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(theme.resolved.accent.color.opacity(0.14), lineWidth: 0.8)
        }
    }

    private var sendButton: some View {
        AssistantSendButton(
            theme: theme,
            isEnabled: isProcessing || (!trimmedText.isEmpty && selectedRuntimeReady),
            isProcessing: isProcessing,
            metrics: composerMetrics
        ) {
            if isProcessing {
                onStop()
            } else {
                submitCurrentText()
            }
        }
        .help(isProcessing ? "Stop" : "Send")
        .accessibilityLabel(isProcessing ? "Stop generating" : "Send message")
    }

    private func openFilePicker() {
        Task { @MainActor in
            await Task.yield()

            let panel = NSOpenPanel()
            panel.allowsMultipleSelection = true
            var allowedTypes: [UTType] = [.pdf, .plainText, .png, .jpeg, .json, .commaSeparatedText]
            if let markdownType = UTType(filenameExtension: "md") {
                allowedTypes.insert(markdownType, at: 2)
            }
            panel.allowedContentTypes = allowedTypes
            panel.canChooseDirectories = false

            let urls = await presentFilePicker(panel)
            guard !urls.isEmpty else { return }

            let attachments = await FileAttachmentBuilder.buildAll(from: urls)
            for attachment in attachments {
                chat.addAttachment(attachment)
            }

            // Phase R.4 — also mint a companion `ContextAttachment`
            // per file so downstream surfaces (R.5 grant parser,
            // future tool-dispatch gate) see a canonical
            // `file://{absolutePath}` resource with Live + Read/Write
            // capabilities. Legacy `FileAttachment` still carries the
            // preview / mimetype / size payload the model uses today;
            // the ContextAttachment carries the R.4 manifest that the
            // Rust-side `attached_resource_allows` check will consume.
            for url in urls {
                guard let contextAttachment = ComposerReferenceHelpers.fileContextAttachment(
                    for: url,
                    displayName: url.lastPathComponent
                ) else { continue }
                chat.addContextAttachment(contextAttachment)
            }
        }
    }

    @MainActor
    private func presentFilePicker(_ panel: NSOpenPanel) async -> [URL] {
        await withCheckedContinuation { continuation in
            let handler: (NSApplication.ModalResponse) -> Void = { response in
                continuation.resume(returning: response == .OK ? panel.urls : [])
            }

            if let window = NSApp.keyWindow ?? NSApp.mainWindow {
                panel.beginSheetModal(for: window, completionHandler: handler)
            } else {
                panel.begin(completionHandler: handler)
            }
        }
    }

    private func iconForType(_ type: AttachmentType) -> String {
        switch type {
        case .image: return "photo"
        case .pdf: return "doc.richtext"
        case .csv: return "tablecells"
        case .text: return "doc.text"
        case .other: return "paperclip"
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
        case .file:
            // Phase R.4: file-kind attachments carry their Live /
            // Snapshot mode in the manifest. Summarise appropriately.
            if attachment.resourceMode == .snapshot {
                return "Read attached pasted snapshot"
            } else {
                return "Read + Edit attached file"
            }
        }
    }

    private func revokePermissionGrant(_ id: String) {
        if id.hasPrefix("context:"), let contextID = id.split(separator: ":", maxSplits: 1).last {
            chat.removeContextAttachment(String(contextID))
            return
        }
        if id.hasPrefix("file:"), let fileID = id.split(separator: ":", maxSplits: 1).last {
            chat.removeAttachment(String(fileID))
        }
    }

    private func submitCurrentText() {
        if showMentionDropdown {
            _ = handleMentionOverlayCommand(.confirm)
            return
        }
        if showSlashMenu {
            _ = handleSlashOverlayCommand(.confirm)
            return
        }

        guard !trimmedText.isEmpty, !isProcessing, selectedRuntimeReady else { return }
        let predictedCapability = ChatCapability.predictIntent(
            text: trimmedText,
            isCloudProvider: isCloudSelection
        ).predicted
        if predictedCapability == .agent,
           let operatingMode {
            let supportedModes = MainChatOperatingModePreference.supportedModes(
                for: inference,
                availableModes: availableOperatingModes
            )
            if supportedModes.contains(.agent) {
                operatingMode.wrappedValue = .agent
            }
        }
        chat.queuePendingSlashCommand(activeSelectedSlashCommand)
        onSubmit(trimmedText)
        text = ""
        composerHeight = ChatComposerInputMetrics.minHeight
        selectedSlashCommand = nil
        showMentionDropdown = false
        referencePopoverStyle = .mention
        mentionKeyboardIndex = 0
        mentionPickerAutofocus = false
        mentionFilter = ""
        referenceSearch.reset()
    }

    private func applyPendingComposerDraftIfNeeded() {
        let revision = chat.pendingComposerDraftRevision
        guard revision != lastConsumedDraftRevision else { return }
        lastConsumedDraftRevision = revision

        guard let draft = chat.consumePendingComposerDraft() else { return }
        text = draft
        selectedSlashCommand = nil
        refreshSlashMenu(for: draft)
        isFocused = true
    }

    private func attachMentionReference(_ choice: ComposerReferenceChoice) {
        // Phase R.4 — pass the active vault's stable ID so the
        // ContextAttachment gets populated with a canonical
        // `vault://{vaultId}/note/{relativePath}` URI at pick time.
        // The URI powers the R.5 grant parser and (future) tool-check
        // gate. `lastPathComponent` mirrors the convention used by
        // `AppBootstrap.initializeRustResourceServiceIfReady` so both
        // ends agree on the vault identity.
        let vaultId = vaultSync.vaultURL?.lastPathComponent
        chat.addContextAttachment(
            ComposerReferenceHelpers.contextAttachment(
                for: choice,
                vaultId: vaultId
            )
        )
        text = ComposerReferenceHelpers.removingTrailingMention(from: text)
        showMentionDropdown = false
        referencePopoverStyle = .mention
        mentionKeyboardIndex = 0
        mentionPickerAutofocus = false
        mentionFilter = ""
        referenceSearch.reset()
    }

    private func dismissReferencePopover() {
        showMentionDropdown = false
        mentionKeyboardIndex = 0
        mentionPickerAutofocus = false
        mentionFilter = ""
        referenceSearch.reset()
    }

    private func openContextualShadowHit(_ hit: ContextualShadowsState.RecallHit) {
        switch hit.kind {
        case .note:
            NoteWindowManager.shared.open(pageId: hit.id)
        case .chat:
            MiniChatWindowController.shared.openChat(hit.id)
        }
        contextualShadows.closePanel()
    }

    private func updateMentionReferenceSearch(filter: String) {
        let trimmed = filter.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            referenceSearch.reset()
            return
        }
        referenceSearch.update(
            filter: trimmed,
            manifest: ambientManifest,
            vaultSync: vaultSync
        )
    }

    // MARK: - Contextual Shadows Recall (200ms debounce)
    // Patch 7 / AMBIENT_RECALL_WIRING_PLAN §5 — schedule an off-MainActor
    // recall query 200ms after the last keystroke in the chat composer.
    // The actual encoder + HNSW search runs inside
    // `ContextualShadowsState.requestRecall`, which dispatches to
    // `Task.detached(priority: .utility)`. This hop only applies the 200ms
    // debounce and captures the snapshot. No-op when the V0 flag is OFF.
    private func scheduleContextualShadowsRecall(for snapshotText: String) {
        recallDebounceBox.task?.cancel()
        guard contextualShadows.isEnabled else { return }
        guard let bootstrap = AppBootstrap.shared else { return }
        let instantRecall = bootstrap.instantRecallService
        let originId = chat.activeChatId.flatMap(UUID.init(uuidString:)) ?? UUID()
        let state = contextualShadows
        recallDebounceBox.task = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            let snapshot = RecallContextSnapshot(
                text: snapshotText,
                kind: .chat,
                originId: originId
            )
            state.requestRecall(snapshot: snapshot, instantRecall: instantRecall)
        }
    }

    private func recentChats() -> [SDChat] {
        var descriptor = SDChat.recentChatsDescriptor
        descriptor.fetchLimit = 20
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            Log.app.error(
                "ChatInputBar: failed to fetch recent chats: \(error.localizedDescription, privacy: .public)"
            )
            return []
        }
    }
}

// Patch 7 / AMBIENT_RECALL_WIRING_PLAN §5 — small reference box that holds
// the in-flight recall debounce task. Lives as `@State` on the ChatInputBar
// struct so SwiftUI never tries to diff the Task value on each re-render.
// Read/write only happens from the @MainActor-isolated composer hook.
@MainActor
final class ChatRecallDebounceBox {
    var task: Task<Void, Never>?
    init() {}
}

enum ChatComposerReturnBehavior: Equatable {
    case submit
    case insertNewline
    case systemDefault
    case ignore
}

enum ChatComposerOverlayCommand: Equatable {
    case moveDown
    case moveUp
    case confirm
    case cancel
}

enum ChatComposerKeyHandling {
    static func isReturnCommand(_ commandSelector: Selector) -> Bool {
        commandSelector == #selector(NSResponder.insertNewline(_:))
            || commandSelector == #selector(NSResponder.insertLineBreak(_:))
    }

    static func overlayCommand(
        for commandSelector: Selector,
        modifierFlags: NSEvent.ModifierFlags
    ) -> ChatComposerOverlayCommand? {
        let flags = semanticModifierFlags(modifierFlags)
        guard flags.isEmpty else { return nil }

        if commandSelector == #selector(NSResponder.moveDown(_:)) {
            return .moveDown
        }
        if commandSelector == #selector(NSResponder.moveUp(_:)) {
            return .moveUp
        }
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            return .cancel
        }
        if isReturnCommand(commandSelector) {
            return .confirm
        }
        return nil
    }

    static func returnBehavior(
        modifierFlags: NSEvent.ModifierFlags,
        trimmedText: String,
        isProcessing: Bool
    ) -> ChatComposerReturnBehavior {
        let flags = semanticModifierFlags(modifierFlags)
        let normalizedText = trimmedText.trimmingCharacters(in: .whitespacesAndNewlines)

        if flags == [.shift] {
            return .insertNewline
        }
        if flags.isEmpty {
            return (!normalizedText.isEmpty && !isProcessing) ? .submit : .ignore
        }
        return .systemDefault
    }

    static func semanticModifierFlags(_ modifierFlags: NSEvent.ModifierFlags) -> NSEvent.ModifierFlags {
        var flags = modifierFlags.intersection(.deviceIndependentFlagsMask)
        flags.remove(.numericPad)
        flags.remove(.function)
        return flags
    }
}

enum ChatComposerInputMetrics {
    static let fontSize: CGFloat = 14
    static let maxVisibleLines = 8
    static let horizontalInset: CGFloat = 10
    static let verticalInset: CGFloat = 4
    static let placeholderTopPadding: CGFloat = 4
    static let minimumHeightPadding: CGFloat = 4
    static let lineHeight = lineHeight(for: fontSize)
    static let minHeight = minHeight(for: fontSize)
    static let maxHeight = maxHeight(for: fontSize)

    static func lineHeight(for fontSize: CGFloat) -> CGFloat {
        let font = NSFont.systemFont(ofSize: fontSize)
        return ceil(font.ascender - font.descender + font.leading)
    }

    static func minHeight(for fontSize: CGFloat) -> CGFloat {
        lineHeight(for: fontSize) + (verticalInset * 2) + minimumHeightPadding
    }

    static func maxHeight(for fontSize: CGFloat) -> CGFloat {
        (lineHeight(for: fontSize) * CGFloat(maxVisibleLines)) + (verticalInset * 2)
    }

    static func clampedHeight(for contentHeight: CGFloat) -> CGFloat {
        clampedHeight(for: contentHeight, fontSize: fontSize)
    }

    static func clampedHeight(for contentHeight: CGFloat, fontSize: CGFloat) -> CGFloat {
        min(max(contentHeight, minHeight(for: fontSize)), maxHeight(for: fontSize))
    }
}

struct ChatComposerTextEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var height: CGFloat
    @Binding var isFocused: Bool

    let theme: EpistemosTheme
    let fontSize: CGFloat
    let isProcessing: Bool
    let onCommand: ((Selector, NSEvent.ModifierFlags) -> Bool)?
    let onSubmit: () -> Void

    init(
        text: Binding<String>,
        height: Binding<CGFloat>,
        isFocused: Binding<Bool>,
        theme: EpistemosTheme,
        fontSize: CGFloat = ChatComposerInputMetrics.fontSize,
        isProcessing: Bool,
        onCommand: ((Selector, NSEvent.ModifierFlags) -> Bool)? = nil,
        onSubmit: @escaping () -> Void
    ) {
        _text = text
        _height = height
        _isFocused = isFocused
        self.theme = theme
        self.fontSize = fontSize
        self.isProcessing = isProcessing
        self.onCommand = onCommand
        self.onSubmit = onSubmit
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView(frame: .zero)
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        scrollView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let textView = ChatComposerNativeTextView(frame: .zero)
        textView.delegate = context.coordinator
        textView.string = text
        textView.isRichText = false
        textView.importsGraphics = false
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.minSize = NSSize(width: 0, height: ChatComposerInputMetrics.minHeight(for: fontSize))
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.textContainerInset = NSSize(
            width: ChatComposerInputMetrics.horizontalInset,
            height: ChatComposerInputMetrics.verticalInset
        )
        textView.allowsUndo = true
        textView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.textContainer?.containerSize = NSSize(
            width: 0,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineFragmentPadding = 0
        textView.onWidthChange = { [weak textView] in
            guard let textView else { return }
            context.coordinator.updateHeight(for: textView)
        }

        context.coordinator.applyTheme(theme, to: textView)
        scrollView.documentView = textView
        context.coordinator.updateHeight(for: textView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = scrollView.documentView as? ChatComposerNativeTextView else { return }

        if textView.string != text {
            textView.string = text
        }

        context.coordinator.applyTheme(theme, to: textView)
        context.coordinator.updateHeight(for: textView)

        guard let window = textView.window else { return }
        if isFocused, window.firstResponder !== textView {
            window.makeFirstResponder(textView)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ChatComposerTextEditor
        private var pendingHeight: CGFloat?

        init(parent: ChatComposerTextEditor) {
            self.parent = parent
        }

        func textDidBeginEditing(_ notification: Notification) {
            // Fix: [Issue - Modifying state during view update]
            // Defer binding mutation to next run loop to avoid re-entrant SwiftUI update.
            DispatchQueue.main.async { [weak self] in
                self?.parent.isFocused = true
            }
        }

        func textDidEndEditing(_ notification: Notification) {
            // Fix: [Issue - Modifying state during view update]
            // Defer binding mutation to next run loop to avoid re-entrant SwiftUI update.
            DispatchQueue.main.async { [weak self] in
                self?.parent.isFocused = false
            }
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? ChatComposerNativeTextView else { return }
            let newText = textView.string
            // Defer binding mutation to avoid re-entrant SwiftUI update.
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if self.parent.text != newText {
                    self.parent.text = newText
                }
            }
            updateHeight(for: textView)
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            let modifierFlags = NSApp.currentEvent?.modifierFlags ?? []
            if parent.onCommand?(commandSelector, modifierFlags) == true {
                return true
            }

            guard ChatComposerKeyHandling.isReturnCommand(commandSelector) else { return false }

            let behavior = ChatComposerKeyHandling.returnBehavior(
                modifierFlags: modifierFlags,
                trimmedText: parent.text.trimmingCharacters(in: .whitespacesAndNewlines),
                isProcessing: parent.isProcessing
            )

            switch behavior {
            case .submit:
                parent.onSubmit()
                return true
            case .ignore:
                return true
            case .insertNewline, .systemDefault:
                return false
            }
        }

        func applyTheme(_ theme: EpistemosTheme, to textView: ChatComposerNativeTextView) {
            textView.font = NSFont.systemFont(ofSize: parent.fontSize)
            textView.textColor = NSColor(theme.resolved.foreground.color)
            textView.insertionPointColor = NSColor(theme.resolved.foreground.color)
        }

        func updateHeight(for textView: ChatComposerNativeTextView) {
            guard
                let textContainer = textView.textContainer,
                let layoutManager = textView.layoutManager
            else { return }

            layoutManager.ensureLayout(for: textContainer)
            let usedRect = layoutManager.usedRect(for: textContainer)
            let contentHeight = ceil(usedRect.height + (textView.textContainerInset.height * 2))
            let clampedHeight = ChatComposerInputMetrics.clampedHeight(
                for: contentHeight,
                fontSize: parent.fontSize
            )

            if abs(parent.height - clampedHeight) > 0.5, pendingHeight != clampedHeight {
                pendingHeight = clampedHeight
                // Defer binding mutation to avoid re-entrant SwiftUI update.
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    if abs(self.parent.height - clampedHeight) > 0.5 {
                        self.parent.height = clampedHeight
                    }
                    self.pendingHeight = nil
                }
            }

            textView.enclosingScrollView?.hasVerticalScroller =
                contentHeight > (ChatComposerInputMetrics.maxHeight(for: parent.fontSize) + 0.5)
        }
    }
}

final class ChatComposerNativeTextView: NSTextView {
    var onWidthChange: (() -> Void)?

    override func setFrameSize(_ newSize: NSSize) {
        let widthChanged = abs(frame.size.width - newSize.width) > 0.5
        super.setFrameSize(newSize)
        if widthChanged {
            onWidthChange?()
        }
    }
}

enum FileAttachmentBuilder {
    nonisolated static let maxPreviewBytes = 262_144
    nonisolated static let maxPreviewCharacters = 2_000

    nonisolated static func buildAll(from urls: [URL]) async -> [FileAttachment] {
        await withTaskGroup(of: (Int, FileAttachment).self, returning: [FileAttachment].self) {
            group in
            for (index, url) in urls.enumerated() {
                group.addTask {
                    (index, await build(from: url))
                }
            }

            var ordered: [(Int, FileAttachment)] = []
            ordered.reserveCapacity(urls.count)

            for await result in group {
                ordered.append(result)
            }

            ordered.sort { $0.0 < $1.0 }
            return ordered.map(\.1)
        }
    }

    nonisolated static func build(from url: URL) async -> FileAttachment {
        await Task.detached(priority: .utility) {
            buildSync(from: url)
        }.value
    }

    private nonisolated static func buildSync(from url: URL) -> FileAttachment {
        let gainedSecurityScope = url.startAccessingSecurityScopedResource()
        defer {
            if gainedSecurityScope {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let name = url.lastPathComponent
        let ext = url.pathExtension.lowercased()
        let size = fileSize(for: url)
        let (type, mimeType) = classify(pathExtension: ext)
        let preview = previewText(for: url, type: type, size: size)

        return FileAttachment(
            id: UUID().uuidString,
            name: name,
            type: type,
            uri: url.absoluteString,
            size: size,
            mimeType: mimeType,
            preview: preview
        )
    }

    private nonisolated static func fileSize(for url: URL) -> Int {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            guard let size = attributes[.size] as? Int else {
                Log.pipeline.error(
                    "FileAttachmentBuilder: missing file size attribute for \(url.lastPathComponent, privacy: .public)"
                )
                return 0
            }
            return size
        } catch {
            Log.pipeline.error(
                "FileAttachmentBuilder: failed to read file size for \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            return 0
        }
    }

    private nonisolated static func classify(pathExtension ext: String) -> (AttachmentType, String) {
        switch ext {
        case "png", "jpg", "jpeg", "gif", "webp", "heic":
            return (.image, "image/\(ext == "jpg" ? "jpeg" : ext)")
        case "pdf":
            return (.pdf, "application/pdf")
        case "csv":
            return (.csv, "text/csv")
        case "txt", "md", "swift", "ts", "js", "py", "json":
            return (.text, "text/plain")
        default:
            return (.other, "application/octet-stream")
        }
    }

    private nonisolated static func previewText(for url: URL, type: AttachmentType, size: Int) -> String? {
        guard type == .text || type == .csv else { return nil }
        guard size > 0, size <= maxPreviewBytes else { return nil }
        let data: Data
        do {
            data = try previewData(for: url)
        } catch {
            Log.pipeline.error(
                "FileAttachmentBuilder: failed to read preview for \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
        guard !data.isEmpty else { return nil }

        guard let preview = FoundationSafety.decodedText(from: data) else { return nil }
        guard preview.count > maxPreviewCharacters else { return preview }
        return String(preview.prefix(maxPreviewCharacters)) + "\n...(truncated)"
    }

    private nonisolated static func previewData(for url: URL) throws -> Data {
        let handle = try FileHandle(forReadingFrom: url)
        defer {
            do {
                try handle.close()
            } catch {
                Log.pipeline.error(
                    "FileAttachmentBuilder: failed to close preview handle for \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)"
                )
            }
        }
        return try handle.read(upToCount: maxPreviewBytes) ?? Data()
    }
}

// MARK: - Provider Badge

/// Compact badge showing the active LLM provider with brand icon + name + color.
private struct ProviderBadge: View {
    let provider: LLMProviderType

    @Environment(UIState.self) private var ui
    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: provider.iconName)
                .font(.epSmall)
                .fontWeight(.semibold)
            Text(provider.displayName)
                .font(.epSmall)
                .fontWeight(.bold)
                .textCase(.uppercase)
                .tracking(0.3)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(provider.badgeColor.opacity(0.12)))
        .foregroundStyle(provider.badgeColor)
    }
}
