import SwiftUI

/// Custom landing-only search bar, Material 3 inspired.
///
/// Design language:
///   - 56pt tall, 20pt corner radius — rounded but not oval
///   - Leading: search glyph. Trailing: submit button.
///   - Subtle elevation (1pt stroke + soft drop shadow). Focus state
///     thickens the stroke and tints it with the theme accent.
///   - SF Mono 14pt text so the bar reads as "quick search," not chat.
///   - Completely bespoke — does NOT reuse `ChatComposerTextEditor` or
///     any other composer. This is the only bar that emerges from the
///     landing wave; every other bar in the app stays untouched.
///
/// Functional scope (this first iteration): plain text input + submit +
/// dismiss. Mentions, attachments, and the capability pill are not part
/// of this bar. The user can open a full chat via Cmd+Enter or by
/// clicking the mode hint.
struct LandingWaveSearchBar: View {
    @Binding var text: String
    let onSubmit: (String) -> Void
    let onDismiss: () -> Void

    @Environment(UIState.self) private var ui
    @FocusState private var focused: Bool

    private var theme: EpistemosTheme { ui.theme }
    private var trimmed: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(theme.mutedForeground.opacity(0.75))

            TextField("", text: $text, prompt: promptText)
                .textFieldStyle(.plain)
                .font(.system(size: 14, weight: .regular, design: .monospaced))
                .foregroundStyle(theme.fontAccent)
                .focused($focused)
                .submitLabel(.search)
                .onSubmit { fireSubmit() }
                .onExitCommand { onDismiss() }

            if !trimmed.isEmpty {
                Button(action: fireSubmit) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(theme.fontAccent)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 56)
        .background(barBackground)
        .overlay(barStroke)
        .shadow(
            color: shadowColor,
            radius: focused ? 16 : 10,
            x: 0,
            y: focused ? 6 : 4
        )
        .animation(.spring(response: 0.18, dampingFraction: 0.78), value: focused)
        .animation(.spring(response: 0.18, dampingFraction: 0.78), value: trimmed.isEmpty)
        .onAppear {
            // Defer focus by one runloop so the emergence animation can begin
            // before the caret blink starts — small but noticeably less
            // jarring than focusing on the first frame.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                focused = true
            }
        }
    }

    private var promptText: Text {
        Text("Search or ask…")
            .font(.system(size: 14, weight: .regular, design: .monospaced))
            .foregroundColor(theme.mutedForeground.opacity(0.45))
    }

    private var barBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(theme.card)
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                theme.fontAccent.opacity(0.02),
                                .clear,
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
    }

    private var barStroke: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(
                focused
                    ? theme.fontAccent.opacity(0.55)
                    : theme.fontAccent.opacity(0.15),
                lineWidth: focused ? 1.4 : 1
            )
    }

    private var shadowColor: Color {
        theme.isDark
            ? Color.black.opacity(0.45)
            : Color.black.opacity(0.12)
    }

    private func fireSubmit() {
        guard !trimmed.isEmpty else { return }
        onSubmit(trimmed)
    }
}
