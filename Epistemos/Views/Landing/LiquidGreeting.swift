import SwiftUI

struct LiquidGreeting: View {
    nonisolated static let restingGreeting = "Greetings, Twin"

    @Environment(UIState.self) private var ui
    var compact: Bool = false
    @Binding var retractNow: Bool
    var onRetractComplete: (() -> Void)? = nil

    @State private var displayText = Self.restingGreeting
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
        plainGreeting(text: shouldAnimate ? displayText : Self.restingGreeting)
        .frame(height: compact ? 40 : 180)
        .padding(.horizontal, compact ? 20 : 100)
        .task(id: taskKey) {
            if retractNow {
                await retractText()
                return
            }

            guard shouldAnimate else {
                displayText = Self.restingGreeting
                return
            }

            displayText = ""
            try? await Task.sleep(for: .milliseconds(50))
            guard !Task.isCancelled else { return }
            await typewriterLoop()
        }
    }

    private func plainGreeting(text: String) -> some View {
        HStack(alignment: .center, spacing: 2) {
            Text(text)
                .font(greetingFont)
                .foregroundStyle(greetingColor)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .shadow(
            color: compact ? .clear : (theme.isDark ? theme.fontAccent.opacity(0.12) : .clear),
            radius: compact ? 0 : 8
        )
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
            let current = activePlaylist[phraseIndex]
            let next = activePlaylist[(phraseIndex + 1) % activePlaylist.count]

            // Type the current phrase (from whatever is already on screen).
            let keepFrom = sharedPrefixLength(displayText, current.text)
            await typeFrom(current.text, startAt: keepFrom)
            guard !Task.isCancelled else { return }

            // Hold.
            try? await Task.sleep(for: .seconds(current.durationSeconds))
            guard !Task.isCancelled else { return }

            // Backspace only the suffix that differs from the next phrase.
            // e.g. "Greetings, Brainiac" → "Greetings, Researcher" only erases "Brainiac".
            let keepTo = sharedPrefixLength(current.text, next.text)
            await untypeTo(current.text, stopAt: keepTo)
            guard !Task.isCancelled else { return }

            try? await Task.sleep(for: .milliseconds(320))
            phraseIndex = (phraseIndex + 1) % activePlaylist.count
        }
    }

    /// Number of leading characters shared between two strings.
    private func sharedPrefixLength(_ a: String, _ b: String) -> Int {
        var count = 0
        for (ca, cb) in zip(a, b) {
            guard ca == cb else { break }
            count += 1
        }
        return count
    }

    @MainActor
    private func typeFrom(_ phrase: String, startAt: Int) async {
        guard !phrase.isEmpty else {
            displayText = ""
            return
        }
        // Skip characters already on screen.
        let start = max(startAt, 0)
        if start == 0 { displayText = "" }
        for index in (start + 1)...phrase.count {
            guard !Task.isCancelled else { return }
            displayText = String(phrase.prefix(index))
            try? await Task.sleep(for: .milliseconds(Int.random(in: 45...75)))
        }
    }

    @MainActor
    private func untypeTo(_ phrase: String, stopAt: Int) async {
        var index = phrase.count
        let floor = max(stopAt, 0)
        while index > floor && !Task.isCancelled {
            index -= 1
            displayText = String(phrase.prefix(index))
            try? await Task.sleep(for: .milliseconds(Int.random(in: 20...40)))
        }
    }
}
