import SwiftUI
import UniformTypeIdentifiers
import AgentTools

private enum EpistemosMessageBarLayout {
    static let maxWidth: CGFloat = 620
    static let horizontalPadding: CGFloat = 11
    static let topPadding: CGFloat = 9
    static let bottomPadding: CGFloat = 7
    static let controlRowSpacing: CGFloat = 4
    static let controlRowTopPadding: CGFloat = 6
    static let controlRowMinHeight: CGFloat = 28
}

struct InputSectionView: View {
    @Bindable var viewModel: AgentViewModel
    @FocusState.Binding var isTaskFieldFocused: Bool
    var selectedTab: ScriptTab?
    @State private var showSuggestions = false
    @State private var selectedSuggestionIndex = 0
    @State private var hoveredSuggestionIndex = -1
    @State private var showInlineSettings = false

    var body: some View {
        if let tab = selectedTab {
            messageBarContainer {
                pastedTextChips(tab: tab)
                tabInputRow(tab: tab)
            }
            .onDrop(of: [.fileURL, .text], isTargeted: nil) { providers in
                handleDrop(providers, tab: tab)
            }
        } else {
            messageBarContainer {
                pastedTextChips(tab: nil)
                mainInputRow
            }
            .onDrop(of: [.fileURL, .text], isTargeted: nil) { providers in
                handleDrop(providers, tab: nil)
            }
        }
    }

    @ViewBuilder
    private func messageBarContainer<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            content()
        }
        .padding(.vertical, 10)
        .frame(maxWidth: EpistemosMessageBarLayout.maxWidth)
        .overlay(alignment: .bottom) {
            suggestionsDropdown
                .offset(y: -88)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .background(AgentSkin.bg)
    }

    @ViewBuilder
    private func tabInputRow(tab: ScriptTab) -> some View {
        composerShell {
            TextField(
                placeholder(for: tab),
                text: Binding(
                    get: { tab.taskInput },
                    set: { tab.taskInput = $0 }
                ),
                axis: .vertical
            )
            .focused($isTaskFieldFocused)
            .modifier(ComposerTextFieldChrome { viewModel.inputFieldWidth = $0 - 24 })
            .onKeyPress(.tab) { acceptSuggestion { tab.taskInput = $0 } }
            .onKeyPress(.escape) { dismissSuggestionsIfNeeded() }
            .onChange(of: tab.taskInput) { _, newValue in updateSuggestions(for: newValue) }
            .onSubmit {
                showSuggestions = false
                if !tab.taskInput.isEmpty {
                    viewModel.runTabTask(tab: tab)
                }
            }
        } controls: {
            composerControls(
                tab: tab,
                isBusy: tab.isBusy,
                hasText: !tab.taskInput.isEmpty,
                runDisabled: tab.taskInput.isEmpty || {
                    let provider = tab.llmConfig?.provider ?? viewModel.selectedProvider
                    return provider == .claude && viewModel.apiKey.isEmpty
                }(),
                clear: { tab.taskInput = "" },
                stop: {
                    if tab.isLLMRunning {
                        viewModel.stopTabTask(tab: tab)
                    } else if tab.isRunning {
                        viewModel.cancelScriptTab(id: tab.id)
                    }
                },
                run: { viewModel.runTabTask(tab: tab) }
            )
        }
    }

    @ViewBuilder
    private var mainInputRow: some View {
        composerShell {
            TextField(placeholder(for: nil), text: $viewModel.taskInput, axis: .vertical)
                .focused($isTaskFieldFocused)
                .modifier(ComposerTextFieldChrome { viewModel.inputFieldWidth = max(0, $0 - 24) })
                .onKeyPress(.tab) { acceptSuggestion { viewModel.taskInput = $0 } }
                .onKeyPress(.escape) { dismissSuggestionsIfNeeded() }
                .onChange(of: viewModel.taskInput) { _, newValue in updateSuggestions(for: newValue) }
                .onSubmit {
                    showSuggestions = false
                    if !viewModel.taskInput.isEmpty {
                        viewModel.run()
                    }
                }
        } controls: {
            composerControls(
                tab: nil,
                isBusy: viewModel.isRunning || viewModel.isThinking,
                hasText: !viewModel.taskInput.isEmpty,
                runDisabled: viewModel.taskInput.isEmpty || (viewModel.selectedProvider == .claude && viewModel.apiKey.isEmpty),
                clear: { viewModel.taskInput = "" },
                stop: { viewModel.stop() },
                run: { viewModel.run() }
            )
        }
    }

    private func placeholder(for tab: ScriptTab?) -> String {
        guard let tab else { return "Message Epistemos..." }
        if tab.isMessagesTab { return "Message recipient..." }
        if tab.isMainTab { return "Message Epistemos..." }
        return "Message \(tab.scriptName)..."
    }

    @ViewBuilder
    private func composerControls(
        tab: ScriptTab?,
        isBusy: Bool,
        hasText: Bool,
        runDisabled: Bool,
        clear: @escaping () -> Void,
        stop: @escaping () -> Void,
        run: @escaping () -> Void
    ) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: EpistemosMessageBarLayout.controlRowSpacing) {
                modeBadge(tab: tab, maxWidth: 112)
                inputButtons
                Spacer(minLength: 8)
                modelSettingsButton(tab: tab, maxWidth: 210)
                taskActionButtons(
                    isBusy: isBusy,
                    hasText: hasText,
                    runDisabled: runDisabled,
                    clear: clear,
                    stop: stop,
                    run: run
                )
            }

            HStack(spacing: EpistemosMessageBarLayout.controlRowSpacing) {
                modeBadge(tab: tab, maxWidth: 88)
                compactToolsMenu
                Spacer(minLength: 8)
                modelSettingsButton(tab: tab, maxWidth: 168)
                taskActionButtons(
                    isBusy: isBusy,
                    hasText: hasText,
                    runDisabled: runDisabled,
                    clear: clear,
                    stop: stop,
                    run: run
                )
            }

            HStack(spacing: EpistemosMessageBarLayout.controlRowSpacing) {
                compactToolsMenu
                modelSettingsButton(tab: tab, maxWidth: 156)
                Spacer(minLength: 4)
                taskActionButtons(
                    isBusy: isBusy,
                    hasText: hasText,
                    runDisabled: runDisabled,
                    clear: clear,
                    stop: stop,
                    run: run
                )
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Current Input Binding

    private var currentInput: Binding<String> {
        if let tab = selectedTab {
            return Binding(get: { tab.taskInput }, set: { tab.taskInput = $0 })
        }
        return $viewModel.taskInput
    }

    // MARK: - Suggestions

    private var suggestions: [String] {
        let raw = currentInput.wrappedValue
        // Skip suggestion matching for long inputs — avoids main-thread stall from
        // repeated lowercased()/contains() across history on every keystroke.
        guard !raw.isEmpty, raw.count <= 120 else { return [] }
        let query = raw.lowercased()
        let history = viewModel.currentTabPromptHistory
        let matches = history.reversed().filter {
            $0.lowercased().contains(query) && $0.lowercased() != query
        }
        var seen = Set<String>()
        return matches.filter { seen.insert($0).inserted }.prefix(1).map { $0 }
    }

    @ViewBuilder
    private var suggestionsDropdown: some View {
        let items = suggestions
        if showSuggestions && !items.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.offset) { idx, suggestion in
                    Button {
                        currentInput.wrappedValue = suggestion
                        showSuggestions = false
                    } label: {
                        HStack(spacing: 6) {
                            Button {
                                showSuggestions = false
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.red.opacity(0.7))
                            }
                            .buttonStyle(.plain)
                            .help("Dismiss suggestions")
                            .frame(width: 14)
                            Text(suggestion)
                                .font(AgentSkin.mono(11))
                                .lineLimit(1)
                                .truncationMode(.tail)
                            Spacer()
                            if idx == selectedSuggestionIndex {
                                Text("Tab")
                                    .font(AgentSkin.pixel(10))
                                    .foregroundStyle(.tertiary)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Color.secondary.opacity(0.15))
                                    .cornerRadius(3)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .background(
                        hoveredSuggestionIndex == idx ? Color.blue.opacity(0.2) :
                            idx == selectedSuggestionIndex ? Color.accentColor.opacity(0.15) : Color.clear
                    )
                    .onHover { hovering in
                        hoveredSuggestionIndex = hovering ? idx : -1
                    }
                }
            }
            .background(AgentSkin.surface)
            .cornerRadius(AgentSkin.radius)
            .overlay(RoundedRectangle(cornerRadius: AgentSkin.radius).stroke(AgentSkin.border, lineWidth: 1))
            // Epistemos: flat — no drop shadow (theme hairline delineates the popover)
            .padding(.horizontal, 8)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }

    @ViewBuilder
    private func composerShell<Editor: View, Controls: View>(
        @ViewBuilder editor: () -> Editor,
        @ViewBuilder controls: () -> Controls
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            editor()

            HStack(spacing: EpistemosMessageBarLayout.controlRowSpacing) {
                controls()
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: EpistemosMessageBarLayout.controlRowMinHeight)
            .padding(.top, EpistemosMessageBarLayout.controlRowTopPadding)
        }
        .padding(.horizontal, EpistemosMessageBarLayout.horizontalPadding)
        .padding(.top, EpistemosMessageBarLayout.topPadding)
        .padding(.bottom, EpistemosMessageBarLayout.bottomPadding)
        .background(AgentSkin.surface.opacity(0.78))
        .overlay(RoundedRectangle(cornerRadius: AgentSkin.radius).stroke(AgentSkin.border.opacity(0.78), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: AgentSkin.radius))
    }

    @ViewBuilder
    private func modeBadge(tab: ScriptTab?, maxWidth: CGFloat) -> some View {
        let isRunning = (tab?.isBusy ?? false) || (tab == nil && (viewModel.isRunning || viewModel.isThinking))
        HStack(spacing: 5) {
            Image(systemName: tab == nil ? "cpu" : "square.stack.3d.up")
                .font(.system(size: 11, weight: .semibold))
            Text(tab?.scriptName ?? "Act")
                .font(AgentSkin.pixel(12))
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .foregroundStyle(isRunning ? AgentSkin.accent : AgentSkin.textDim)
        .padding(.horizontal, 8)
        .frame(height: 24)
        .frame(maxWidth: maxWidth, alignment: .leading)
        .background(isRunning ? AgentSkin.accent.opacity(0.11) : AgentSkin.surface.opacity(0.64))
        .overlay(Rectangle().stroke(isRunning ? AgentSkin.accent.opacity(0.36) : AgentSkin.border.opacity(0.5), lineWidth: 1))
        .help(tab?.displayTitle ?? "Act")
    }

    @ViewBuilder
    private func modelSettingsButton(tab: ScriptTab?, maxWidth: CGFloat) -> some View {
        let pair = providerModelPair(for: tab)
        Button {
            showInlineSettings.toggle()
            viewModel.fetchModelsIfNeeded(for: pair.provider)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: providerIcon(pair.provider))
                    .font(.system(size: 11, weight: .semibold))
                Text(pair.provider.displayName)
                    .font(AgentSkin.pixel(12))
                    .lineLimit(1)
                Text(pair.model)
                    .font(AgentSkin.mono(11))
                    .foregroundStyle(AgentSkin.textDim)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .foregroundStyle(AgentSkin.text)
            .padding(.horizontal, 8)
            .frame(height: 24)
            .frame(maxWidth: maxWidth, alignment: .leading)
            .background(AgentSkin.surface.opacity(0.72))
            .overlay(Rectangle().stroke(AgentSkin.border.opacity(0.55), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .help("Model and provider settings")
        .accessibilityLabel("Model settings")
        .accessibilityValue("\(pair.provider.displayName), \(pair.model)")
        .popover(isPresented: $showInlineSettings, attachmentAnchor: .rect(.bounds), arrowEdge: .bottom) {
            SettingsView(viewModel: viewModel)
        }
    }

    private var compactToolsMenu: some View {
        Menu {
            Button {
                viewModel.captureScreenshot()
            } label: {
                Label("Attach screenshot", systemImage: "camera")
            }
            Button {
                viewModel.pasteImageFromClipboard()
            } label: {
                Label("Paste image", systemImage: "photo.on.rectangle.angled")
            }
            Button {
                viewModel.toggleDictation()
            } label: {
                Label(viewModel.isListening ? "Stop dictation" : "Start dictation", systemImage: viewModel.isListening ? "mic.fill" : "mic")
            }
            Button {
                viewModel.toggleHotwordListening()
            } label: {
                Label(viewModel.isHotwordListening ? "Stop hotword" : "Listen for Epistemos", systemImage: viewModel.isHotwordListening ? "waveform.circle.fill" : "waveform.circle")
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 28)
        }
        .menuStyle(.borderlessButton)
        .buttonStyle(.plain)
        .modifier(ComposerIconChrome(isActive: viewModel.isListening || viewModel.isHotwordListening))
        .help("Composer tools")
        .accessibilityLabel("Composer tools")
    }

    private func providerModelPair(for tab: ScriptTab?) -> (provider: APIProvider, model: String) {
        if let tab {
            return viewModel.resolvedLLMConfig(for: tab)
        }
        let provider = viewModel.selectedProvider
        return (provider, viewModel.globalModelForProvider(provider))
    }

    private func providerIcon(_ provider: APIProvider) -> String {
        switch provider {
        case .ollama, .localOllama, .lmStudio, .vLLM:
            return "externaldrive.connected.to.line.below"
        case .foundationModel:
            return "apple.logo"
        case .codex:
            return "chevron.left.forwardslash.chevron.right"
        default:
            return "cloud"
        }
    }

    private func updateSuggestions(for newValue: String) {
        selectedSuggestionIndex = 0
        guard newValue.count <= 120 else {
            if showSuggestions { showSuggestions = false }
            return
        }
        showSuggestions = viewModel.taskAutoComplete && !newValue.isEmpty && !suggestions.isEmpty
    }

    private func acceptSuggestion(_ apply: (String) -> Void) -> KeyPress.Result {
        if showSuggestions && !suggestions.isEmpty {
            let idx = min(selectedSuggestionIndex, suggestions.count - 1)
            apply(suggestions[idx])
            showSuggestions = false
            return .handled
        }
        return .ignored
    }

    private func dismissSuggestionsIfNeeded() -> KeyPress.Result {
        if showSuggestions {
            showSuggestions = false
            return .handled
        }
        return .ignored
    }

    /// Handle drag-and-drop of text files into the input area.
    /// Works regardless of whether the text field has focus.
    private func handleDrop(_ providers: [NSItemProvider], tab: ScriptTab? = nil) -> Bool {
        for provider in providers {
            // File URLs — read text content
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { data, _ in
                    guard let urlData = data as? Data,
                          let url = URL(dataRepresentation: urlData, relativeTo: nil) else { return }
                    // Read text-based files
                    guard let content = try? String(contentsOfFile: url.path, encoding: .utf8) else { return }
                    let filename = url.lastPathComponent
                    let dropped = "[\(filename)]\n\(content)"
                    DispatchQueue.main.async {
                        if let tab {
                            tab.taskInput += (tab.taskInput.isEmpty ? "" : " ") + dropped
                        } else {
                            viewModel.taskInput += (viewModel.taskInput.isEmpty ? "" : " ") + dropped
                            isTaskFieldFocused = true
                        }
                    }
                }
                return true
            }
            // Plain text
            if provider.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { data, _ in
                    guard let text = data as? String, !text.isEmpty else { return }
                    DispatchQueue.main.async {
                        if let tab {
                            tab.taskInput += (tab.taskInput.isEmpty ? "" : " ") + text
                        } else {
                            viewModel.taskInput += (viewModel.taskInput.isEmpty ? "" : " ") + text
                            isTaskFieldFocused = true
                        }
                    }
                }
                return true
            }
        }
        return false
    }

    // MARK: - Pasted Text Chips

    /// Row of removable chips for long-text attachments captured on Cmd+V.
    @ViewBuilder
    private func pastedTextChips(tab: ScriptTab?) -> some View {
        let items: [PastedText] = tab?.pastedTexts ?? viewModel.pastedTexts
        if !items.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(items) { item in
                        pastedTextChip(item, tab: tab)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    @ViewBuilder
    private func pastedTextChip(_ item: PastedText, tab: ScriptTab?) -> some View {
        let (head, tail) = Self.chipPreview(for: item.text, edge: 48)
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Image(systemName: "doc.plaintext")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text("Pasted text")
                    .font(AgentSkin.pixel(12))
                Text("\(item.text.count.formatted()) chars")
                    .font(AgentSkin.mono(10))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 6)
                Button {
                    if let tab {
                        tab.pastedTexts.removeAll { $0.id == item.id }
                    } else {
                        viewModel.pastedTexts.removeAll { $0.id == item.id }
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Remove attachment")
            }
            Text(head.isEmpty ? " " : (tail.isEmpty ? head : "\(head) …"))
                .font(AgentSkin.mono(10))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
            Text(tail.isEmpty ? " " : tail)
                .font(AgentSkin.mono(10))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.head)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .frame(minWidth: 160, maxWidth: 360, alignment: .leading)
        .background(AgentSkin.surface)
        .clipShape(RoundedRectangle(cornerRadius: AgentSkin.radius))
        .overlay(RoundedRectangle(cornerRadius: AgentSkin.radius).stroke(AgentSkin.border, lineWidth: 1))
        .help("\(head)\n…\n\(tail)")
    }

    /// Build a single-line preview: first `edge` and last `edge` visible chars,
    /// with whitespace/newlines collapsed so the chip stays compact.
    private static func chipPreview(for text: String, edge: Int) -> (String, String) {
        let flat = text
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
        let collapsed = flat.split(separator: " ", omittingEmptySubsequences: true).joined(separator: " ")
        guard collapsed.count > edge * 2 else { return (collapsed, "") }
        let head = String(collapsed.prefix(edge))
        let tail = String(collapsed.suffix(edge))
        return (head, tail)
    }

    private var inputButtons: some View {
        let buttonWidth: CGFloat = 28
        return HStack(spacing: 5) {
                Button { viewModel.captureScreenshot() } label: {
                    Image(systemName: "camera")
                        .frame(width: buttonWidth)
                }
                .buttonStyle(.plain)
                .modifier(ComposerIconChrome())
                .controlSize(.small)
                .help("Take a screenshot to attach")
                .accessibilityLabel("Screenshot")

                Button { viewModel.pasteImageFromClipboard() } label: {
                    Image(systemName: "photo.on.rectangle.angled")
                        .frame(width: buttonWidth)
                }
                .buttonStyle(.plain)
                .modifier(ComposerIconChrome())
                .controlSize(.small)
                .help("Paste image from clipboard")
                .accessibilityLabel("Paste image")

                Button { viewModel.toggleDictation() } label: {
                    Image(systemName: viewModel.isListening ? "mic.fill" : "mic")
                        .foregroundStyle(viewModel.isListening ? Color.orange : .primary)
                        .frame(width: buttonWidth)
                }
                .buttonStyle(.plain)
                .modifier(ComposerIconChrome(isActive: viewModel.isListening))
                .controlSize(.small)
                .help(viewModel.isListening ? "Stop dictation" : "Start dictation")
                .accessibilityLabel("Dictation")
                .accessibilityValue(viewModel.isListening ? "Recording" : "Off")

                Button { viewModel.toggleHotwordListening() } label: {
                    Image(systemName: viewModel.isHotwordListening ? "waveform.circle.fill" : "waveform.circle")
                        .foregroundStyle(
                            viewModel.isHotwordListening
                                ? (viewModel.isHotwordCapturing ? Color.green : Color.orange)
                                : .primary
                        )
                        .frame(width: buttonWidth)
                }
                .buttonStyle(.plain)
                .modifier(ComposerIconChrome(isActive: viewModel.isHotwordListening))
                .controlSize(.small)
                .help(
                    viewModel.isHotwordListening
                        ? (viewModel.isHotwordCapturing ? "Capturing command..." : "Listening for \"Epistemos\" - click to stop")
                        : "Say \"Epistemos\" to send a voice command"
                )
                .accessibilityLabel("Hotword")
                .accessibilityValue(viewModel.isHotwordListening ? (viewModel.isHotwordCapturing ? "Capturing" : "Listening") : "Off")
        }
    }

    @ViewBuilder
    private func taskActionButtons(
        isBusy: Bool,
        hasText: Bool,
        runDisabled: Bool,
        clear: @escaping () -> Void,
        stop: @escaping () -> Void,
        run: @escaping () -> Void
    ) -> some View {
        Button(action: isBusy ? stop : clear) {
            Image(systemName: isBusy ? "stop.fill" : "xmark")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isBusy ? Color.red : AgentSkin.textDim)
                .frame(width: 28, height: 24)
        }
        .buttonStyle(.plain)
        .modifier(ComposerIconChrome(isActive: isBusy))
        .disabled(!isBusy && !hasText)
        .help(isBusy ? "Stop current task" : "Clear input")
        .accessibilityLabel(isBusy ? "Stop task" : "Clear input")

        Button(action: run) {
            Image(systemName: "arrow.up")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(runDisabled ? AgentSkin.textDim.opacity(0.55) : AgentSkin.bg)
                .frame(width: 30, height: 26)
                .background(runDisabled ? AgentSkin.surface : AgentSkin.accent)
                .overlay(Rectangle().stroke(AgentSkin.border.opacity(runDisabled ? 0.7 : 0), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(runDisabled)
        .help("Send")
        .accessibilityLabel("Send")
    }

    private static let tabColors: [Color] = [
        .orange, .purple, .pink, .cyan, .mint, .indigo, .teal, .yellow
    ]

    static func tabColor(for tabId: UUID, in tabs: [ScriptTab]) -> Color {
        guard let index = tabs.firstIndex(where: { $0.id == tabId }) else { return .red }
        return tabColors[index % tabColors.count]
    }
}

private struct ComposerTextFieldChrome: ViewModifier {
    let onWidthChange: (CGFloat) -> Void

    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .font(AgentSkin.mono(15))
            .padding(.vertical, 5)
            .padding(.horizontal, 0)
            .lineLimit(2...14)
            .background(GeometryReader { geo in
                Color.clear.onChange(of: geo.size.width, initial: true) { _, width in
                    onWidthChange(width)
                }
            })
    }
}

private struct ComposerIconChrome: ViewModifier {
    var isActive = false

    func body(content: Content) -> some View {
        content
            .frame(height: 24)
            .foregroundStyle(isActive ? AgentSkin.accent : AgentSkin.textDim)
            .background(isActive ? AgentSkin.accent.opacity(0.12) : Color.clear)
            .overlay(Rectangle().stroke(isActive ? AgentSkin.accent.opacity(0.35) : AgentSkin.border.opacity(0.45), lineWidth: 1))
    }
}
