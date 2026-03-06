import SwiftUI

/// SwiftUI overlay positioned over the Metal-rendered dialogue box.
/// Uses RetroGaming.ttf for the authentic FFT dialogue aesthetic.
struct DialogueOverlayView: View {
    @Environment(GraphState.self) private var graphState
    @Bindable var chatState: DialogueChatState
    var onSubmit: (String) -> Void
    var onDismiss: () -> Void

    @FocusState private var inputFocused: Bool

    private let chromeFont = Font.custom("RetroGaming", size: 10)
    private let titleFont = Font.system(size: 18, weight: .semibold, design: .serif)
    private let bodyFont = Font.system(size: 18, weight: .regular, design: .serif)
    private let inputFont = Font.system(size: 14, weight: .medium, design: .rounded)

    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: 22) {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    transcript
                    inputBar
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                portraitPanel
                    .frame(width: min(124, proxy.size.width * 0.24))
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(dialogueBackground)
            .overlay(dialogueBorder)
            .shadow(color: .black.opacity(0.28), radius: 18, y: 8)
        }
        .padding(2)
        .onAppear { inputFocused = true }
        .onExitCommand { onDismiss() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(chatState.activeNodeLabel)
                .font(titleFont)
                .foregroundStyle(palette.primaryText)

            Text(chatState.activeProfile.archetype.title)
                .font(chromeFont)
                .foregroundStyle(palette.secondaryText)
                .textCase(.uppercase)

            Text("\(graphState.dialoguePresentationTheme.displayName) Link Active")
                .font(chromeFont)
                .foregroundStyle(palette.secondaryText)
                .textCase(.uppercase)
        }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(palette.headerFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(palette.chromeStroke, lineWidth: 2)
        )
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 10) {
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
                .fill(palette.transcriptFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(palette.softStroke, lineWidth: 1)
        )
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            Text(">")
                .font(chromeFont)
                .foregroundStyle(palette.secondaryText)
                .frame(width: 14, alignment: .leading)

            TextField("Ask \(chatState.activeNodeLabel) something...", text: $chatState.inputText)
                .font(inputFont)
                .foregroundStyle(palette.primaryText)
                .textFieldStyle(.plain)
                .focused($inputFocused)
                .submitLabel(.send)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(palette.transcriptFill.opacity(0.92))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(palette.softStroke, lineWidth: 1)
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    inputFocused = true
                }
                .onSubmit {
                    onSubmit(chatState.inputText)
                }

            Button("Send") {
                onSubmit(chatState.inputText)
            }
            .buttonStyle(.plain)
            .font(chromeFont)
            .foregroundStyle(.white)
            .frame(minWidth: 68, minHeight: 42)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(palette.actionFill)
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(minHeight: 68)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(palette.inputFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(palette.chromeStroke, lineWidth: 2)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            inputFocused = true
        }
    }

    private var portraitPanel: some View {
        VStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [palette.portraitTop, palette.portraitBottom],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(palette.chromeStroke, lineWidth: 2)
                )
                .overlay(
                    VStack(spacing: 8) {
                        Image(systemName: chatState.activeProfile.portrait.symbol)
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(palette.primaryText)
                        Text(chatState.activeProfile.portrait.crestLabel)
                            .font(chromeFont)
                            .foregroundStyle(palette.secondaryText)
                            .textCase(.uppercase)
                        Text(nodeInitials)
                            .font(.system(size: 18, weight: .bold, design: .serif))
                            .foregroundStyle(palette.secondaryText)
                    }
                    .padding(10)
                )

            VStack(alignment: .leading, spacing: 8) {
                statusPill(label: chatState.activeProfile.care.mood.displayName)
                meterRow(label: "Health", value: chatState.activeProfile.care.health, tint: palette.healthTint)
                meterRow(label: "Focus", value: chatState.activeProfile.care.attention, tint: palette.attentionTint)
                if !chatState.activeProfile.focusKeywords.isEmpty {
                    keywordChips
                }
                Text(chatState.activeProfile.summary)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var dialogueBackground: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [palette.backgroundTop, palette.backgroundBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }

    private var dialogueBorder: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .stroke(palette.chromeStroke, lineWidth: 3)
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
                .foregroundStyle(palette.secondaryText)
                .textCase(.uppercase)

            Text(displayText)
                .font(bodyFont)
                .foregroundStyle(palette.primaryText)
                .lineSpacing(5)
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
                    ? palette.userBubbleFill
                    : palette.assistantBubbleFill
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(
                    message.role == .user
                    ? palette.userBubbleStroke
                    : palette.softStroke,
                    lineWidth: 1
                )
        )
    }

    private var keywordChips: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Focus")
                .font(chromeFont)
                .foregroundStyle(palette.secondaryText)
                .textCase(.uppercase)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(chatState.activeProfile.focusKeywords, id: \.self) { keyword in
                        Text(keyword.capitalized)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(palette.primaryText)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(palette.keywordFill)
                            )
                    }
                }
            }
        }
    }

    private func statusPill(label: String) -> some View {
        Text(label)
            .font(chromeFont)
            .foregroundStyle(palette.primaryText)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(palette.keywordFill)
            )
    }

    private func meterRow(label: String, value: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(chromeFont)
                    .foregroundStyle(palette.secondaryText)
                Spacer()
                Text("\(Int(value * 100))")
                    .font(chromeFont)
                    .foregroundStyle(palette.secondaryText)
            }
            GeometryReader { proxy in
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(palette.meterTrack)
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(tint)
                            .frame(width: proxy.size.width * value)
                    }
            }
            .frame(height: 8)
        }
    }

    private var palette: DialoguePalette {
        switch graphState.dialoguePresentationTheme {
        case .tactics:
            DialoguePalette(
                backgroundTop: Color(red: 0.93, green: 0.88, blue: 0.77),
                backgroundBottom: Color(red: 0.86, green: 0.79, blue: 0.67),
                headerFill: Color(red: 0.84, green: 0.74, blue: 0.58),
                transcriptFill: Color(red: 0.97, green: 0.94, blue: 0.88),
                inputFill: Color(red: 0.90, green: 0.84, blue: 0.73),
                portraitTop: Color(red: 0.90, green: 0.82, blue: 0.67),
                portraitBottom: Color(red: 0.78, green: 0.67, blue: 0.50),
                primaryText: Color(red: 0.16, green: 0.10, blue: 0.07),
                secondaryText: Color(red: 0.42, green: 0.31, blue: 0.18),
                chromeStroke: Color(red: 0.33, green: 0.23, blue: 0.15),
                softStroke: Color(red: 0.51, green: 0.42, blue: 0.29),
                actionFill: Color(red: 0.28, green: 0.24, blue: 0.49),
                userBubbleFill: Color(red: 0.88, green: 0.92, blue: 0.99),
                userBubbleStroke: Color(red: 0.40, green: 0.55, blue: 0.82),
                assistantBubbleFill: Color(red: 0.98, green: 0.95, blue: 0.90),
                keywordFill: Color(red: 0.87, green: 0.80, blue: 0.68),
                meterTrack: Color(red: 0.73, green: 0.66, blue: 0.56),
                healthTint: Color(red: 0.37, green: 0.67, blue: 0.33),
                attentionTint: Color(red: 0.43, green: 0.48, blue: 0.87)
            )
        case .nocturne:
            DialoguePalette(
                backgroundTop: Color(red: 0.13, green: 0.12, blue: 0.20),
                backgroundBottom: Color(red: 0.08, green: 0.09, blue: 0.15),
                headerFill: Color(red: 0.22, green: 0.18, blue: 0.31),
                transcriptFill: Color(red: 0.12, green: 0.13, blue: 0.20),
                inputFill: Color(red: 0.17, green: 0.16, blue: 0.25),
                portraitTop: Color(red: 0.24, green: 0.20, blue: 0.36),
                portraitBottom: Color(red: 0.14, green: 0.13, blue: 0.23),
                primaryText: Color(red: 0.95, green: 0.92, blue: 0.84),
                secondaryText: Color(red: 0.76, green: 0.70, blue: 0.57),
                chromeStroke: Color(red: 0.65, green: 0.56, blue: 0.38),
                softStroke: Color(red: 0.43, green: 0.39, blue: 0.30),
                actionFill: Color(red: 0.29, green: 0.45, blue: 0.70),
                userBubbleFill: Color(red: 0.17, green: 0.22, blue: 0.34),
                userBubbleStroke: Color(red: 0.39, green: 0.55, blue: 0.80),
                assistantBubbleFill: Color(red: 0.18, green: 0.16, blue: 0.27),
                keywordFill: Color(red: 0.24, green: 0.24, blue: 0.35),
                meterTrack: Color(red: 0.20, green: 0.19, blue: 0.29),
                healthTint: Color(red: 0.37, green: 0.71, blue: 0.51),
                attentionTint: Color(red: 0.69, green: 0.57, blue: 0.86)
            )
        }
    }
}

private struct DialoguePalette {
    let backgroundTop: Color
    let backgroundBottom: Color
    let headerFill: Color
    let transcriptFill: Color
    let inputFill: Color
    let portraitTop: Color
    let portraitBottom: Color
    let primaryText: Color
    let secondaryText: Color
    let chromeStroke: Color
    let softStroke: Color
    let actionFill: Color
    let userBubbleFill: Color
    let userBubbleStroke: Color
    let assistantBubbleFill: Color
    let keywordFill: Color
    let meterTrack: Color
    let healthTint: Color
    let attentionTint: Color
}
