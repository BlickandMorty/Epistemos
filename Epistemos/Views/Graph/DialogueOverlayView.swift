import SwiftUI

/// SwiftUI overlay positioned over the Metal-rendered dialogue box.
/// Uses RetroGaming.ttf for the authentic FFT dialogue aesthetic.
struct DialogueOverlayView: View {
    @Bindable var chatState: DialogueChatState
    var screenRect: CGRect
    var onSubmit: (String) -> Void
    var onDismiss: () -> Void

    @FocusState private var inputFocused: Bool

    private let retroFont = Font.custom("RetroGaming", size: 13)
    private let retroFontSmall = Font.custom("RetroGaming", size: 11)

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Nameplate
            Text(chatState.activeNodeLabel)
                .font(retroFontSmall)
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, 8)
                .padding(.vertical, 2)

            // Chat messages
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(chatState.messages.enumerated()), id: \.element.id) { index, message in
                            messageView(message, isLast: index == chatState.messages.count - 1)
                        }
                    }
                    .padding(.horizontal, 8)
                }
                .onChange(of: chatState.messages.count) {
                    if let last = chatState.messages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }

            // Input field
            HStack(spacing: 4) {
                Text(">")
                    .font(retroFont)
                    .foregroundStyle(.white.opacity(0.6))
                TextField("", text: $chatState.inputText)
                    .font(retroFont)
                    .foregroundStyle(.white)
                    .textFieldStyle(.plain)
                    .focused($inputFocused)
                    .onSubmit {
                        onSubmit(chatState.inputText)
                    }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .frame(width: screenRect.width - 4, height: screenRect.height - 4)
        .position(x: screenRect.midX, y: screenRect.midY)
        .onAppear { inputFocused = true }
        .onExitCommand { onDismiss() }
    }

    @ViewBuilder
    private func messageView(_ message: DialogueChatState.Message, isLast: Bool) -> some View {
        let displayText: String = {
            if isLast && message.role == .assistant && chatState.revealedCharCount < message.text.count {
                return String(message.text.prefix(chatState.revealedCharCount))
            }
            return message.text
        }()

        Text(displayText)
            .font(retroFont)
            .foregroundStyle(message.role == .user ? .cyan : .white)
            .id(message.id)
    }
}
