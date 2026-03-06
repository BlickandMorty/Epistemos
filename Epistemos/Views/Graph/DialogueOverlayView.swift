import SwiftUI

/// SwiftUI overlay positioned over the Metal-rendered dialogue box.
/// Uses RetroGaming.ttf for the authentic FFT dialogue aesthetic.
struct DialogueOverlayView: View {
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
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 12) {
                    header
                    transcript
                    inputBar
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                portraitPanel
                    .frame(width: min(92, proxy.size.width * 0.22))
            }
            .padding(14)
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
                .foregroundStyle(Color(red: 0.18, green: 0.11, blue: 0.07))

            Text("Dialogue Link Active")
                .font(chromeFont)
                .foregroundStyle(Color(red: 0.42, green: 0.31, blue: 0.18))
                .textCase(.uppercase)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(red: 0.84, green: 0.74, blue: 0.58))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(red: 0.33, green: 0.23, blue: 0.15), lineWidth: 2)
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
            .padding(.horizontal, 2)
            .onChange(of: chatState.messages.count) {
                if let last = chatState.messages.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(red: 0.97, green: 0.94, blue: 0.88))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(red: 0.51, green: 0.42, blue: 0.29), lineWidth: 1)
        )
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            Text(">")
                .font(chromeFont)
                .foregroundStyle(Color(red: 0.42, green: 0.31, blue: 0.18))

            TextField("Ask this node something...", text: $chatState.inputText)
                .font(inputFont)
                .foregroundStyle(Color(red: 0.16, green: 0.10, blue: 0.07))
                .textFieldStyle(.plain)
                .focused($inputFocused)
                .onSubmit {
                    onSubmit(chatState.inputText)
                }

            Button("Send") {
                onSubmit(chatState.inputText)
            }
            .buttonStyle(.plain)
            .font(chromeFont)
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule(style: .continuous)
                    .fill(Color(red: 0.28, green: 0.24, blue: 0.49))
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(red: 0.90, green: 0.84, blue: 0.73))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(red: 0.33, green: 0.23, blue: 0.15), lineWidth: 2)
        )
    }

    private var portraitPanel: some View {
        VStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.90, green: 0.82, blue: 0.67),
                            Color(red: 0.78, green: 0.67, blue: 0.50)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color(red: 0.33, green: 0.23, blue: 0.15), lineWidth: 2)
                )
                .overlay(
                    VStack(spacing: 8) {
                        Text(nodeInitials)
                            .font(.system(size: 30, weight: .bold, design: .serif))
                            .foregroundStyle(Color(red: 0.24, green: 0.16, blue: 0.10))
                        Text("Node Persona")
                            .font(chromeFont)
                            .foregroundStyle(Color(red: 0.39, green: 0.28, blue: 0.17))
                            .textCase(.uppercase)
                    }
                    .padding(10)
                )

            Text(chatState.isStreaming ? "Speaking" : "Listening")
                .font(chromeFont)
                .foregroundStyle(Color(red: 0.42, green: 0.31, blue: 0.18))
                .textCase(.uppercase)
        }
    }

    private var dialogueBackground: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.93, green: 0.88, blue: 0.77),
                        Color(red: 0.86, green: 0.79, blue: 0.67)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }

    private var dialogueBorder: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .stroke(Color(red: 0.33, green: 0.23, blue: 0.15), lineWidth: 3)
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
                .foregroundStyle(Color(red: 0.42, green: 0.31, blue: 0.18))
                .textCase(.uppercase)

            Text(displayText)
                .font(bodyFont)
                .foregroundStyle(Color(red: 0.16, green: 0.10, blue: 0.07))
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
                    ? Color(red: 0.88, green: 0.92, blue: 0.99)
                    : Color(red: 0.98, green: 0.95, blue: 0.90)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(
                    message.role == .user
                    ? Color(red: 0.40, green: 0.55, blue: 0.82)
                    : Color(red: 0.51, green: 0.42, blue: 0.29),
                    lineWidth: 1
                )
        )
    }
}
