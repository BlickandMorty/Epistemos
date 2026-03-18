import SwiftUI

struct LiquidGreeting: View {
    nonisolated static let restingGreeting = "welcome back"

    @Environment(UIState.self) private var ui
    var compact: Bool = false
    @Binding var retractNow: Bool
    var onRetractComplete: (() -> Void)? = nil

    @State private var displayText = Self.restingGreeting
    @State private var cursorVisible = true

    private var theme: EpistemosTheme { ui.theme }
    private var playlist: [LandingGreetingPhrase] { ui.resolvedLandingGreetingPlaylist }
    private var greetingFont: Font { AppDisplayTypography.font(size: compact ? 22 : 44) }
    private var greetingColor: Color {
        theme.fontAccent.opacity(theme.isDark ? 0.94 : 0.9)
    }

    private var shouldAnimate: Bool {
        ui.activePanel == .home && !ui.windowOccluded && ui.landingGreetingTypewriterEnabled
    }

    private var taskKey: String {
        "\(shouldAnimate)_\(retractNow)_\(ui.landingGreetingPlaylistSignature)"
    }

    var body: some View {
        plainGreeting(
            text: shouldAnimate ? displayText : Self.restingGreeting,
            showsCursor: shouldAnimate && cursorVisible
        )
        .frame(height: compact ? 40 : 180)
        .padding(.horizontal, compact ? 20 : 100)
        .task(id: taskKey) {
            if retractNow {
                await retractText()
                return
            }

            guard shouldAnimate else {
                displayText = Self.restingGreeting
                cursorVisible = false
                return
            }

            displayText = ""
            cursorVisible = true
            try? await Task.sleep(for: .milliseconds(50))
            guard !Task.isCancelled else { return }

            let blinkTask = Task { @MainActor in
                await cursorBlinkLoop()
            }
            await typewriterLoop()
            blinkTask.cancel()
        }
    }

    private func plainGreeting(text: String, showsCursor: Bool) -> some View {
        HStack(alignment: .center, spacing: 2) {
            Text(text)
                .font(greetingFont)
                .foregroundStyle(greetingColor)

            if showsCursor {
                Rectangle()
                    .fill(greetingColor)
                    .frame(width: compact ? 8 : 12, height: compact ? 20 : 36)
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                    .opacity(cursorVisible ? 1 : 0)
                    .animation(.easeInOut(duration: 0.3), value: cursorVisible)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .shadow(
            color: compact ? .clear : (theme.isDark ? theme.fontAccent.opacity(0.12) : .clear),
            radius: compact ? 0 : 8
        )
    }

    @MainActor
    private func cursorBlinkLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            cursorVisible.toggle()
        }
    }

    @MainActor
    private func retractText() async {
        guard !displayText.isEmpty else {
            onRetractComplete?()
            return
        }

        while !displayText.isEmpty && !Task.isCancelled {
            displayText.removeLast()
            try? await Task.sleep(for: .milliseconds(15))
        }
        guard !Task.isCancelled else { return }
        onRetractComplete?()
    }

    @MainActor
    private func typewriterLoop() async {
        let activePlaylist = playlist
        guard !activePlaylist.isEmpty else {
            displayText = Self.restingGreeting
            return
        }

        var phraseIndex = 0
        while !Task.isCancelled {
            let phrase = activePlaylist[phraseIndex]
            await typePhrase(phrase.text)
            guard !Task.isCancelled else { return }

            try? await Task.sleep(for: .seconds(phrase.durationSeconds))
            guard !Task.isCancelled else { return }

            await untypePhrase(phrase.text)
            guard !Task.isCancelled else { return }

            try? await Task.sleep(for: .milliseconds(320))
            phraseIndex = (phraseIndex + 1) % activePlaylist.count
        }
    }

    @MainActor
    private func typePhrase(_ phrase: String) async {
        guard !phrase.isEmpty else {
            displayText = ""
            return
        }

        for index in 1...phrase.count {
            guard !Task.isCancelled else { return }
            displayText = String(phrase.prefix(index))
            try? await Task.sleep(for: .milliseconds(Int.random(in: 45...75)))
        }
    }

    @MainActor
    private func untypePhrase(_ phrase: String) async {
        var index = phrase.count
        while index > 0 && !Task.isCancelled {
            index -= 1
            displayText = String(phrase.prefix(index))
            try? await Task.sleep(for: .milliseconds(Int.random(in: 20...40)))
        }
    }
}
