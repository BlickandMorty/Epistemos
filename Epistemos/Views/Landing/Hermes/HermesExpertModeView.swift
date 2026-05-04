import OSLog
import SwiftUI

/// Hermes Expert Mode terminal-styled liquid-glass surface that hosts
/// the input ribbon, the live command palette, and the scrollback
/// transcript. Lives below the hero typewriter on the landing page
/// when the user activates expert mode.
///
/// Visual posture:
/// - Liquid glass background (`.regularMaterial` over a tinted accent
///   wash) with a subtle inner stroke. Reads as a terminal pane that
///   floats over the landing wave.
/// - Monospaced input + transcript. Hero font lives ABOVE this in the
///   landing view (LiquidGreeting), not inside.
/// - Compact when collapsed, expands to a comfortable max width
///   (LandingSearchLayout.maxWidth) when active.
///
/// The dispatcher wiring (HermesExpertModeRunner) is provided by the
/// landing view; this view only knows about state + visuals.
struct HermesExpertModeView: View {
    private static let log = Logger(subsystem: "com.epistemos", category: "HermesExpertMode")

    @Bindable var state: HermesExpertModeState
    var theme: EpistemosTheme
    var onSubmit: (String) -> Void
    var onExit: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var inputFocused: Bool

    private let cornerRadius: CGFloat = 18
    private let maxWidth: CGFloat = LandingSearchLayout.maxWidth
    private let monoFont: Font = .system(size: 13.5, weight: .regular, design: .monospaced)
    private let inputFontSize: CGFloat = 15

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            transcriptArea
            divider
            inputArea
            if state.showingCommandPalette {
                commandPalette
                    .transition(.opacity.combined(with: .offset(y: -4)))
            }
            if let err = state.lastErrorMessage {
                Text(err)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(theme.resolved.accent.color.opacity(0.85))
                    .padding(.horizontal, 14)
                    .padding(.bottom, 6)
                    .transition(.opacity)
            }
            footerHints
        }
        .padding(16)
        .frame(maxWidth: maxWidth)
        .background(glassBackground)
        .overlay(borderStroke)
        .onAppear {
            // Defer focus until the hero typewriter completes per
            // `state.heroReady`; otherwise focus competes with the
            // hidden landing search input and steals first key.
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(60))
                if state.heroReady { inputFocused = true }
            }
        }
        .onChange(of: state.heroReady) { _, ready in
            if ready { inputFocused = true }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18),
                   value: state.showingCommandPalette)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18),
                   value: state.lastErrorMessage)
    }

    // MARK: - Transcript

    private var transcriptArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    if state.transcript.isEmpty {
                        Text("// Type `/help` to list commands. `/ask <q>` for a query. `Esc` exits.")
                            .font(monoFont)
                            .foregroundStyle(theme.textTertiary.opacity(0.7))
                            .padding(.horizontal, 6)
                            .padding(.top, 4)
                    } else {
                        ForEach(state.transcript) { entry in
                            transcriptRow(entry)
                                .id(entry.id)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 6)
                .padding(.vertical, 6)
            }
            .frame(maxHeight: 260)
            .onChange(of: state.transcript.count) { _, _ in
                if let last = state.transcript.last {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.15)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func transcriptRow(_ entry: HermesExpertTranscriptEntry) -> some View {
        if let payload = entry.payload {
            // CANON-COMPLIANT 2026-05-04 (Stage A.4 / GenUI G.3 path).
            // Routes through the canonical GenUIDispatcher per
            // `docs/fusion/COGNITIVE_GENUI_DOCTRINE_2026_05_03.md`.
            // First migrated renderer: `/status` via .keyValueTable.
            // Other 6 commands (/help, /config show, /tokens, /cost,
            // /model list, /search) migrate from .artifact → .payload
            // next; same pattern.
            HermesTranscriptRowFlash(entry: entry, accent: theme.resolved.accent.color) {
                HStack(alignment: .top, spacing: 8) {
                    Text("⌁")
                        .font(monoFont)
                        .foregroundStyle(theme.textPrimary.opacity(0.55))
                        .frame(width: 18, alignment: .leading)
                    GenUIDispatcher.shared.render(payload)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        } else if let artifact = entry.artifact {
            // GENUI-DEFER: hackathon-2026-05-03 (legacy chat-block path,
            // partial implementation). Migrating to .payload above as
            // each renderer in `HermesExpertModeRunner` swaps from
            // `.artifact(Artifact(...))` to `.payload(GenUIPayload(...))`.
            HermesTranscriptRowFlash(entry: entry, accent: theme.resolved.accent.color) {
                HStack(alignment: .top, spacing: 8) {
                    Text("⌁")
                        .font(monoFont)
                        .foregroundStyle(theme.textPrimary.opacity(0.55))
                        .frame(width: 18, alignment: .leading)
                    ArtifactBlockView(artifact: artifact)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        } else {
            let (prefix, color) = transcriptStyling(entry)
            HermesTranscriptRowFlash(entry: entry, accent: theme.resolved.accent.color) {
                HStack(alignment: .top, spacing: 8) {
                    Text(prefix)
                        .font(monoFont)
                        .foregroundStyle(color.opacity(0.7))
                        .frame(width: 18, alignment: .leading)
                    Text(entry.text)
                        .font(monoFont)
                        .foregroundStyle(color)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
            }
        }
    }

    private func transcriptStyling(_ entry: HermesExpertTranscriptEntry) -> (String, Color) {
        switch entry.kind {
        case .userInput:      return (">",  theme.textPrimary)
        case .systemEcho:     return ("·",  theme.textSecondary)
        case .systemResponse: return ("⌁",  theme.textPrimary.opacity(0.92))
        case .info:           return ("∙",  theme.textTertiary)
        case .error:          return ("!",  theme.resolved.accent.color)
        case .artifact:       return ("⌁",  theme.textPrimary.opacity(0.92))  // not used (artifact path renders separately)
        case .payload:        return ("⌁",  theme.textPrimary.opacity(0.92))  // not used (payload path renders separately via GenUIDispatcher)
        }
    }

    // MARK: - Divider

    private var divider: some View {
        Rectangle()
            .fill(theme.textTertiary.opacity(0.15))
            .frame(height: 0.5)
            .padding(.horizontal, 4)
    }

    // MARK: - Input

    private var inputArea: some View {
        HStack(alignment: .center, spacing: 10) {
            Text("hermes ›")
                .font(.system(size: inputFontSize, weight: .medium, design: .monospaced))
                .foregroundStyle(theme.resolved.accent.color.opacity(0.85))
                .padding(.leading, 6)

            TextField("", text: $state.draft, prompt: Text("ask, /command, or @reference")
                .foregroundStyle(theme.mutedForeground.opacity(0.55))
            )
            .textFieldStyle(.plain)
            .focused($inputFocused)
            .font(.system(size: inputFontSize, weight: .regular, design: .monospaced))
            .foregroundStyle(theme.textPrimary)
            .tint(theme.resolved.accent.color)
            .disableAutocorrection(true)
            .onSubmit {
                triggerSubmit()
            }
            .onExitCommand {
                onExit()
            }
            .onChange(of: state.draft) { _, newValue in
                state.updateDraft(newValue)
            }
            .onKeyPress(.downArrow) {
                if state.showingCommandPalette {
                    state.movePaletteSelection(by: 1, matchCount: paletteMatches.count)
                    return .handled
                }
                if let recalled = state.recallNext() {
                    state.draft = recalled
                    return .handled
                }
                return .ignored
            }
            .onKeyPress(.upArrow) {
                if state.showingCommandPalette {
                    state.movePaletteSelection(by: -1, matchCount: paletteMatches.count)
                    return .handled
                }
                if let recalled = state.recallPrev(currentDraft: state.draft) {
                    state.draft = recalled
                    return .handled
                }
                return .ignored
            }
            .onKeyPress(.tab) {
                if state.showingCommandPalette,
                   state.selectedPaletteIndex >= 0,
                   state.selectedPaletteIndex < paletteMatches.count {
                    autofillFromMatch(paletteMatches[state.selectedPaletteIndex])
                    return .handled
                }
                if state.showingCommandPalette, !paletteMatches.isEmpty {
                    autofillFromMatch(paletteMatches[0])
                    return .handled
                }
                return .ignored
            }

            if state.dispatching {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.85)
                    .frame(width: 22, height: 22)
            } else {
                Button(action: triggerSubmit) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(
                            state.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? theme.textTertiary.opacity(0.5)
                            : theme.resolved.accent.color
                        )
                }
                .buttonStyle(.plain)
                .disabled(state.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut(.return, modifiers: [])
                .help("Submit")
            }
        }
        .padding(.vertical, 6)
        .padding(.trailing, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(theme.resolved.foreground.color.opacity(theme.isDark ? 0.06 : 0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(theme.resolved.accent.color.opacity(0.18), lineWidth: 0.6)
        )
    }

    private func triggerSubmit() {
        // If the user has highlighted a palette row but the draft is
        // still just the partial token, autofill instead of submitting
        // an unknown command. Mirrors VS Code / Spotlight behavior.
        if state.showingCommandPalette,
           state.selectedPaletteIndex >= 0,
           state.selectedPaletteIndex < paletteMatches.count,
           paletteMatches[state.selectedPaletteIndex].commandToken != state.draft.trimmingCharacters(in: .whitespacesAndNewlines) {
            autofillFromMatch(paletteMatches[state.selectedPaletteIndex])
            return
        }
        let trimmed = state.draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onSubmit(trimmed)
    }

    // MARK: - Command palette

    private var paletteMatches: [HermesExpertCommandPaletteData.Match] {
        HermesExpertCommandPaletteData.matches(for: state.draft, limit: 6)
    }

    private var commandPalette: some View {
        let matches = paletteMatches
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(matches.enumerated()), id: \.element.id) { idx, match in
                paletteRow(match, isSelected: idx == state.selectedPaletteIndex)
                    .onHover { hovering in
                        if hovering { state.selectedPaletteIndex = idx }
                    }
            }
            if matches.isEmpty {
                Text("// no matching commands")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(theme.textTertiary.opacity(0.7))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(theme.resolved.foreground.color.opacity(theme.isDark ? 0.05 : 0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(theme.textTertiary.opacity(0.12), lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private func paletteRow(_ match: HermesExpertCommandPaletteData.Match, isSelected: Bool) -> some View {
        Button(action: {
            autofillFromMatch(match)
        }) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(isSelected ? "▸" : " ")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(theme.resolved.accent.color)
                    .frame(width: 10, alignment: .leading)
                Text(match.commandToken)
                    .font(.system(size: 12.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(theme.textPrimary)
                    .frame(width: 90, alignment: .leading)
                Text(match.surface.displayName)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(theme.textTertiary)
                    .frame(width: 84, alignment: .leading)
                Text(match.tier.displayName)
                    .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(match.tier == .core
                        ? theme.resolved.accent.color
                        : theme.textTertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(theme.resolved.accent.color.opacity(0.08))
                    )
                Text(match.nativeEquivalent)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(theme.textSecondary.opacity(0.85))
                    .lineLimit(1)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(theme.resolved.accent.color.opacity(0.10))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func autofillFromMatch(_ match: HermesExpertCommandPaletteData.Match) {
        state.draft = match.commandToken + " "
        state.updateDraft(state.draft)
        state.selectedPaletteIndex = -1
        inputFocused = true
    }

    // MARK: - Footer hints

    private var footerHints: some View {
        HStack(spacing: 14) {
            Label("/help", systemImage: "questionmark.circle")
                .labelStyle(MonoHintLabelStyle())
            Label("@notes", systemImage: "at")
                .labelStyle(MonoHintLabelStyle())
            Label("↩ submit", systemImage: "return")
                .labelStyle(MonoHintLabelStyle())
            Spacer(minLength: 0)
            Button {
                onExit()
            } label: {
                Label("⎋ exit", systemImage: "escape")
                    .labelStyle(MonoHintLabelStyle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.top, 2)
        .foregroundStyle(theme.textTertiary)
    }

    // MARK: - Glass background

    private var glassBackground: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.regularMaterial)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(theme.resolved.accent.color.opacity(theme.isDark ? 0.05 : 0.03))
            )
    }

    private var borderStroke: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: [
                        theme.resolved.accent.color.opacity(0.32),
                        theme.resolved.accent.color.opacity(0.08),
                        theme.resolved.accent.color.opacity(0.20),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 0.8
            )
    }
}

private struct MonoHintLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.icon
                .font(.system(size: 10, weight: .medium))
            configuration.title
                .font(.system(size: 10.5, weight: .medium, design: .monospaced))
        }
    }
}

// MARK: - Capability surface display names (UI-only enrichment)

extension HermesCapabilitySurface {
    var displayName: String {
        switch self {
        case .agentTask:        return "agent"
        case .session:          return "session"
        case .configuration:    return "config"
        case .fileData:         return "files"
        case .toolsIntegration: return "tools"
        case .uiDisplay:        return "ui"
        case .persona:          return "persona"
        case .messaging:        return "msg"
        case .advanced:         return "advanced"
        case .toolset:          return "toolset"
        }
    }
}

extension HermesCapabilityTier {
    var displayName: String {
        switch self {
        case .core:     return "CORE"
        case .pro:      return "PRO"
        case .research: return "RESEARCH"
        }
    }
}
