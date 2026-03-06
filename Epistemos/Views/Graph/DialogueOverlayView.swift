import SwiftUI
import AppKit

// MARK: - DialogueOverlayView

struct DialogueOverlayView: View {
    @Environment(GraphState.self) private var graphState
    @Environment(UIState.self) private var ui
    @Bindable var chatState: DialogueChatState
    var onSubmit: (String) -> Void
    var onDismiss: () -> Void

    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                header
                transcript
                inputBar
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .layoutPriority(1)

            portraitRail
                .frame(width: 160)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.thinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(theme.glassBorder, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.10), radius: 10, y: 4)
        .padding(2)
        .onExitCommand { onDismiss() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(chatState.activeNodeLabel)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(theme.foreground)
                .lineLimit(1)

            Text(chatState.activeProfile.archetype.title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(theme.mutedForeground)
                .textCase(.uppercase)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(theme.muted))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(theme.border, lineWidth: 1))
    }

    // MARK: - Transcript

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(chatState.messages.enumerated()), id: \.element.id) { index, message in
                        messageBubble(message, isLast: index == chatState.messages.count - 1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(6)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .onChange(of: chatState.messages.count) {
                if let last = chatState.messages.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(theme.glassBg))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(theme.border, lineWidth: 1))
    }

    @ViewBuilder
    private func messageBubble(_ message: DialogueChatState.Message, isLast: Bool) -> some View {
        let text: String = {
            if isLast, message.role == .assistant, chatState.revealedCharCount < message.text.count {
                return String(message.text.prefix(chatState.revealedCharCount))
            }
            return message.text
        }()

        VStack(alignment: .leading, spacing: 4) {
            Text(message.role == .user ? "You" : chatState.activeNodeLabel)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(theme.mutedForeground)
                .textCase(.uppercase)

            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(theme.foreground)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .id(message.id)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(message.role == .user ? theme.glassBg : theme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(message.role == .user ? theme.accent.opacity(0.3) : theme.border, lineWidth: 1)
        )
    }

    // MARK: - Input Bar (AppKit NSTextField for reliable focus in NSHostingView)

    private var inputBar: some View {
        HStack(spacing: 8) {
            DialogueTextField(
                text: $chatState.inputText,
                placeholder: "Ask \(chatState.activeNodeLabel) something...",
                theme: theme,
                onSubmit: { submitCurrentInput() }
            )
            .frame(maxWidth: .infinity, minHeight: 32)

            Button(action: submitCurrentInput) {
                Text("Send")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(minWidth: 56, minHeight: 32)
                    .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(theme.accent))
            }
            .buttonStyle(.plain)
            .opacity(trimmedInput.isEmpty ? 0.5 : 1.0)
            .disabled(trimmedInput.isEmpty)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(theme.muted))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(theme.border, lineWidth: 1))
    }

    // MARK: - Portrait Rail

    private var portraitRail: some View {
        VStack(spacing: 10) {
            // Icon + label
            VStack(spacing: 6) {
                Image(systemName: chatState.activeProfile.portrait.symbol)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(theme.foreground)
                Text(chatState.activeProfile.portrait.crestLabel)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(theme.mutedForeground)
                    .textCase(.uppercase)
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(theme.muted))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(theme.border, lineWidth: 1))

            // Stats
            VStack(alignment: .leading, spacing: 6) {
                pill(chatState.activeProfile.care.mood.displayName)
                pill(chatState.activeProfile.insight.tier.displayName)
                meter("Health", value: chatState.activeProfile.care.health, tint: theme.emerald)
                meter("Focus", value: chatState.activeProfile.care.attention, tint: theme.indigo)
                meter("Mass", value: chatState.activeProfile.insight.prominence, tint: theme.amber)

                if !chatState.activeProfile.focusKeywords.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(chatState.activeProfile.focusKeywords, id: \.self) { kw in
                                Text(kw.capitalized)
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(theme.foreground)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(theme.muted))
                            }
                        }
                    }
                }

                Text(chatState.activeProfile.summary)
                    .font(.system(size: 10))
                    .foregroundStyle(theme.mutedForeground)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Small Components

    private func pill(_ label: String) -> some View {
        Text(label)
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(theme.foreground)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(Capsule().fill(theme.muted))
    }

    private func meter(_ label: String, value: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(theme.mutedForeground)
                Spacer()
                Text("\(Int(value * 100))")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(theme.mutedForeground)
            }
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(theme.border)
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(tint)
                            .frame(width: geo.size.width * value)
                    }
            }
            .frame(height: 6)
        }
    }

    // MARK: - Helpers

    private var trimmedInput: String {
        chatState.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func submitCurrentInput() {
        let query = trimmedInput
        guard !query.isEmpty else { return }
        chatState.inputText = query
        onSubmit(query)
    }
}

// MARK: - DialogueTextField (AppKit-backed for reliable focus in NSHostingView)

struct DialogueTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var theme: EpistemosTheme
    var onSubmit: () -> Void

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = .systemFont(ofSize: 12, weight: .medium)
        field.placeholderString = placeholder
        field.delegate = context.coordinator
        field.cell?.lineBreakMode = .byTruncatingTail
        // Auto-focus after a short delay to let the hosting view settle.
        DispatchQueue.main.async {
            field.window?.makeFirstResponder(field)
        }
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        if field.stringValue != text {
            field.stringValue = text
        }
        field.placeholderString = placeholder
        field.textColor = NSColor(theme.foreground)
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: DialogueTextField
        init(_ parent: DialogueTextField) { self.parent = parent }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            parent.text = field.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onSubmit()
                return true
            }
            return false
        }
    }
}
