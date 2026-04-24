import SwiftUI

/// Custom landing-only search bar, Material 3 inspired.
///
/// Design language:
///   - Two-row layout. Top row (56pt): search icon + text input + submit.
///     Bottom row (36pt): mode/brain picker + future pills. Total ~104pt.
///   - 20pt corner radius — rounded but not oval
///   - Subtle elevation (1pt stroke + soft drop shadow). Focus state
///     thickens the stroke and tints it with the theme accent.
///   - SF Mono 14pt text so the bar reads as "quick search," not chat.
///   - Completely bespoke — does NOT reuse `ChatComposerTextEditor` or
///     any other composer. This is the only bar that emerges from the
///     landing wave; every other bar in the app stays untouched.
///
/// Functional scope: plain text input + submit + dismiss + brain-picker
/// menu (for switching operating mode and enabling temporary chats).
/// Mentions and attachments are not part of this bar — by design: the
/// landing surface is for quick queries, with the full chat experience
/// reachable via ⌘⇧Return from the bar.
struct LandingWaveSearchBar: View {
    @Binding var text: String
    @Binding var operatingMode: EpistemosOperatingMode
    @Binding var isTemporaryChatEnabled: Bool
    let availableOperatingModes: [EpistemosOperatingMode]
    let onSubmit: (String) -> Void
    let onDismiss: () -> Void

    @Environment(UIState.self) private var ui
    @FocusState private var focused: Bool

    private var theme: EpistemosTheme { ui.theme }
    private var trimmed: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(spacing: 0) {
            topRow
            Divider().opacity(0.18)
            bottomRow
        }
        .background(barBackground)
        .overlay(barStroke)
        .shadow(
            color: shadowColor,
            radius: focused ? 20 : 12,
            x: 0,
            y: focused ? 8 : 5
        )
        .animation(.spring(response: 0.18, dampingFraction: 0.78), value: focused)
        .animation(.spring(response: 0.18, dampingFraction: 0.78), value: trimmed.isEmpty)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                focused = true
            }
        }
    }

    // MARK: - Rows

    private var topRow: some View {
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
                        .font(.system(size: 24, weight: .regular))
                        .foregroundStyle(theme.fontAccent)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.return, modifiers: [])
                .transition(.scale.combined(with: .opacity))
                .help("Send")
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 56)
    }

    private var bottomRow: some View {
        HStack(spacing: 8) {
            ChatBrainPickerMenu(
                operatingMode: $operatingMode,
                availableOperatingModes: availableOperatingModes,
                isTemporaryChatEnabled: $isTemporaryChatEnabled
            )

            if isTemporaryChatEnabled {
                HStack(spacing: 4) {
                    Image(systemName: "eye.slash.fill")
                        .font(.system(size: 10, weight: .semibold))
                    Text("Temporary")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(theme.resolved.accent.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    theme.resolved.accent.color.opacity(0.10),
                    in: Capsule()
                )
                .transition(.opacity.combined(with: .scale))
            }

            Spacer(minLength: 0)

            Text("↩ send    ⎋ dismiss")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(theme.mutedForeground.opacity(0.55))
        }
        .padding(.horizontal, 14)
        .frame(height: 36)
    }

    // MARK: - Chrome

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
