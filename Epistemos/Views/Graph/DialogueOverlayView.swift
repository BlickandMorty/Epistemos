import SwiftUI

/// SwiftUI overlay positioned over the Metal-rendered dialogue box.
/// Glass material background, theme-reactive colors from EpistemosTheme.
struct DialogueOverlayView: View {
    @Environment(GraphState.self) private var graphState
    @Environment(UIState.self) private var ui
    @Bindable var chatState: DialogueChatState
    var onSubmit: (String) -> Void
    var onDismiss: () -> Void

    @FocusState private var inputFocused: Bool

    private var theme: EpistemosTheme { ui.theme }

    private let chromeFont = Font.custom("RetroGaming", size: 9)
    private let titleFont = Font.system(size: 16, weight: .semibold, design: .serif)
    private let bodyFont = Font.system(size: 14, weight: .regular, design: .serif)
    private let inputFont = Font.system(size: 13, weight: .medium, design: .rounded)

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.width < 450 || proxy.size.height < 190
            let railWidth = compact
                ? min(122, proxy.size.width * 0.30)
                : max(164, min(212, proxy.size.width * 0.30))

            HStack(spacing: compact ? 14 : 18) {
                VStack(alignment: .leading, spacing: compact ? 10 : 12) {
                    header(compact: compact)
                    if compact {
                        teaserCard
                    } else {
                        transcript
                        inputBar
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .layoutPriority(1)

                portraitPanel
                    .frame(width: railWidth)
            }
            .padding(compact ? 14 : 18)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(dialogueBackground)
            .overlay(dialogueBorder)
            .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
        }
        .padding(2)
        .onAppear { inputFocused = true }
        .onExitCommand { onDismiss() }
    }

    private func header(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(chatState.activeNodeLabel)
                .font(titleFont)
                .foregroundStyle(theme.foreground)
                .lineLimit(1)

            Text(chatState.activeProfile.archetype.title)
                .font(chromeFont)
                .foregroundStyle(theme.mutedForeground)
                .textCase(.uppercase)

            Text("\(theme.displayName) Link Active")
                .font(chromeFont)
                .foregroundStyle(theme.mutedForeground)
                .textCase(.uppercase)
        }
            .padding(.horizontal, compact ? 12 : 14)
            .padding(.vertical, compact ? 10 : 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(theme.muted)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(theme.glassBorder, lineWidth: 1)
        )
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(chatState.messages.enumerated()), id: \.element.id) { index, message in
                        messageView(message, isLast: index == chatState.messages.count - 1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .onChange(of: chatState.messages.count) {
                if let last = chatState.messages.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(theme.glassBg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(theme.border, lineWidth: 1)
        )
    }

    private var teaserCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(latestDialogueLine)
                .font(bodyFont)
                .foregroundStyle(theme.foreground)
                .lineSpacing(2)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                statusPill(label: chatState.activeProfile.care.mood.displayName)
                statusPill(label: chatState.activeProfile.insight.tier.displayName)
                Spacer(minLength: 0)
                Text("Zoom in to speak")
                    .font(chromeFont)
                    .foregroundStyle(theme.mutedForeground)
                    .textCase(.uppercase)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(theme.glassBg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(theme.border, lineWidth: 1)
        )
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            Text(">")
                .font(chromeFont)
                .foregroundStyle(theme.mutedForeground)
                .frame(width: 14, alignment: .leading)

            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(theme.glassBg)
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(theme.border, lineWidth: 1)
                TextField(
                    "",
                    text: $chatState.inputText,
                    prompt: Text("Ask \(chatState.activeNodeLabel) something...")
                        .foregroundStyle(theme.mutedForeground.opacity(0.8))
                )
                .font(inputFont)
                .foregroundStyle(theme.foreground)
                .textFieldStyle(.plain)
                .focused($inputFocused)
                .submitLabel(.send)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .onSubmit { submitCurrentInput() }
            }
            .frame(maxWidth: .infinity, minHeight: 40)
            .contentShape(Rectangle())
            .onTapGesture {
                inputFocused = true
            }

            Button("Send") {
                submitCurrentInput()
            }
            .buttonStyle(.plain)
            .font(chromeFont)
            .foregroundStyle(.white)
            .frame(minWidth: 72, minHeight: 36)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(theme.accent)
            )
            .opacity(trimmedInput.isEmpty ? 0.55 : 1.0)
            .disabled(trimmedInput.isEmpty)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(minHeight: 56)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(theme.muted)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(theme.glassBorder, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            inputFocused = true
        }
    }

    private var portraitPanel: some View {
        VStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(theme.glassBorder, lineWidth: 1)
                )
                .overlay(
                    VStack(spacing: 8) {
                        Image(systemName: chatState.activeProfile.portrait.symbol)
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(theme.foreground)
                        Text(chatState.activeProfile.portrait.crestLabel)
                            .font(chromeFont)
                            .foregroundStyle(theme.mutedForeground)
                            .textCase(.uppercase)
                        Text(nodeInitials)
                            .font(.system(size: 16, weight: .bold, design: .serif))
                            .foregroundStyle(theme.mutedForeground)
                    }
                    .padding(10)
                )

            VStack(alignment: .leading, spacing: 8) {
                statusRows
                Text("\(chatState.activeProfile.insight.hierarchyLabel) · \(chatState.activeProfile.insight.contentLabel)")
                    .font(chromeFont)
                    .foregroundStyle(theme.mutedForeground)
                meterRow(label: "Health", value: chatState.activeProfile.care.health, tint: theme.emerald)
                meterRow(label: "Focus", value: chatState.activeProfile.care.attention, tint: theme.indigo)
                meterRow(label: "Mass", value: chatState.activeProfile.insight.prominence, tint: theme.amber)
                if !chatState.activeProfile.focusKeywords.isEmpty {
                    keywordChips
                }
                Text(chatState.activeProfile.summary)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.mutedForeground)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var statusRows: some View {
        VStack(alignment: .leading, spacing: 6) {
            statusPill(label: chatState.activeProfile.care.mood.displayName)
            statusPill(label: chatState.activeProfile.insight.tier.displayName)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var dialogueBackground: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(.ultraThinMaterial)
    }

    private var dialogueBorder: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .stroke(theme.glassBorder, lineWidth: 1)
            .padding(1)
    }

    private var nodeInitials: String {
        let parts = chatState.activeNodeLabel
            .split(whereSeparator: \.isWhitespace)
            .prefix(2)
        let initials = parts.compactMap { $0.first }.map(String.init).joined()
        return initials.isEmpty ? "?" : initials
    }

    @ViewBuilder
    private func messageView(_ message: DialogueChatState.Message, isLast: Bool) -> some View {
        let displayText: String = {
            if isLast && message.role == .assistant && chatState.revealedCharCount < message.text.count {
                return String(message.text.prefix(chatState.revealedCharCount))
            }
            return message.text
        }()

        VStack(alignment: .leading, spacing: 6) {
            Text(message.role == .user ? "You" : chatState.activeNodeLabel)
                .font(chromeFont)
                .foregroundStyle(theme.mutedForeground)
                .textCase(.uppercase)

            Text(displayText)
                .font(bodyFont)
                .foregroundStyle(theme.foreground)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .id(message.id)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    message.role == .user
                    ? theme.glassBg
                    : theme.card
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(
                    message.role == .user
                    ? theme.accent.opacity(0.3)
                    : theme.border,
                    lineWidth: 1
                )
        )
    }

    private var keywordChips: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Focus")
                .font(chromeFont)
                .foregroundStyle(theme.mutedForeground)
                .textCase(.uppercase)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(chatState.activeProfile.focusKeywords, id: \.self) { keyword in
                        Text(keyword.capitalized)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(theme.foreground)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(theme.muted)
                            )
                    }
                }
            }
        }
    }

    private func statusPill(label: String) -> some View {
        Text(label)
            .font(chromeFont)
            .foregroundStyle(theme.foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(theme.muted)
            )
    }

    private func meterRow(label: String, value: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(chromeFont)
                    .foregroundStyle(theme.mutedForeground)
                Spacer()
                Text("\(Int(value * 100))")
                    .font(chromeFont)
                    .foregroundStyle(theme.mutedForeground)
            }
            GeometryReader { proxy in
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(theme.border)
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(tint)
                            .frame(width: proxy.size.width * value)
                    }
            }
            .frame(height: 8)
        }
    }

    private var trimmedInput: String {
        chatState.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var latestDialogueLine: String {
        guard let last = chatState.messages.last?.text.trimmingCharacters(in: .whitespacesAndNewlines),
              !last.isEmpty else {
            return chatState.activeProfile.summary
        }
        return last
    }

    private func submitCurrentInput() {
        let query = trimmedInput
        guard !query.isEmpty else {
            inputFocused = true
            return
        }
        chatState.inputText = query
        onSubmit(query)
        inputFocused = true
    }
}
