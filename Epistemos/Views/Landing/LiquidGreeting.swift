import SwiftUI

enum LiquidGreetingTiming {
    nonisolated static func startupDelay() -> Duration { .milliseconds(50) }
    nonisolated static func retractDelay() -> Duration { .milliseconds(15) }
    nonisolated static func holdDelay(for phrase: LandingGreetingPhrase) -> Duration { .seconds(phrase.durationSeconds) }
    nonisolated static func transitionDelay() -> Duration { .milliseconds(320) }

    nonisolated static func typingDelay(forStep step: Int) -> Duration {
        switch normalizedCycleIndex(forStep: step, count: 4) {
        case 0: .milliseconds(48)
        case 1: .milliseconds(56)
        case 2: .milliseconds(64)
        default: .milliseconds(72)
        }
    }

    nonisolated static func untypingDelay(forStep step: Int) -> Duration {
        switch normalizedCycleIndex(forStep: step, count: 4) {
        case 0: .milliseconds(24)
        case 1: .milliseconds(30)
        case 2: .milliseconds(36)
        default: .milliseconds(28)
        }
    }

    private nonisolated static func normalizedCycleIndex(forStep step: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return abs(step) % count
    }
}

struct LiquidGreeting: View {
    nonisolated static let restingGreeting = "Greetings, Learner"

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
        !ui.windowOccluded && ui.landingGreetingTypewriterEnabled
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
            guard await pause(LiquidGreetingTiming.startupDelay()) else { return }
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

    private func pause(_ duration: Duration) async -> Bool {
        do {
            try await Task.sleep(for: duration)
            return !Task.isCancelled
        } catch is CancellationError {
            return false
        } catch {
            return false
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
            guard await pause(LiquidGreetingTiming.retractDelay()) else { return }
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
            guard await pause(LiquidGreetingTiming.holdDelay(for: current)) else { return }

            // Backspace only the suffix that differs from the next phrase.
            // e.g. "Greetings, Brainiac" → "Greetings, Researcher" only erases "Brainiac".
            let keepTo = sharedPrefixLength(current.text, next.text)
            await untypeTo(current.text, stopAt: keepTo)
            guard !Task.isCancelled else { return }

            guard await pause(LiquidGreetingTiming.transitionDelay()) else { return }
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
        guard start < phrase.count else {
            displayText = phrase
            return
        }
        if start == 0 { displayText = "" }
        for index in (start + 1)...phrase.count {
            guard !Task.isCancelled else { return }
            displayText = String(phrase.prefix(index))
            guard await pause(LiquidGreetingTiming.typingDelay(forStep: index)) else { return }
        }
    }

    @MainActor
    private func untypeTo(_ phrase: String, stopAt: Int) async {
        var index = phrase.count
        let floor = max(stopAt, 0)
        while index > floor && !Task.isCancelled {
            index -= 1
            displayText = String(phrase.prefix(index))
            guard await pause(LiquidGreetingTiming.untypingDelay(forStep: index)) else { return }
        }
    }
}
