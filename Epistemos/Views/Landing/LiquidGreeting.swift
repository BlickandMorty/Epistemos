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

    /// Delay between each character typed in the search prompt. Slightly
    /// quicker than the greeting-phrase typewriter so the morph feels
    /// decisive.
    nonisolated static func searchTypingDelay(forStep step: Int) -> Duration {
        switch normalizedCycleIndex(forStep: step, count: 3) {
        case 0: .milliseconds(28)
        case 1: .milliseconds(36)
        default: .milliseconds(32)
        }
    }

    /// Period of one on/off cycle of the search cursor blink.
    nonisolated static func cursorBlinkPeriod() -> Duration { .milliseconds(520) }

    private nonisolated static func normalizedCycleIndex(forStep step: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return abs(step) % count
    }
}

struct LiquidGreeting: View {
    nonisolated static let restingGreeting = "Greetings, Learner"

    @Environment(UIState.self) private var ui
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var compact: Bool = false
    @Binding var retractNow: Bool
    var onRetractComplete: (() -> Void)? = nil
    /// When true, the greeting backspaces to empty, types the search
    /// prompt, then stays idle with a blinking cursor. `searchText` is
    /// appended after the prompt in real time as the user types.
    var searchMode: Bool = false
    /// Live query text driven by the hidden input overlay in LandingView.
    /// Rendered in the same greeting font so it looks like the user is
    /// typing directly where the greeting used to be. No static prompt
    /// prefix is auto-typed — after the backspace, the caret waits and
    /// the user's typed text IS the displayed prompt.
    var searchText: String = ""

    @State private var displayText = Self.restingGreeting
    @State private var searchReady: Bool = false
    @State private var cursorVisible: Bool = true

    private var theme: EpistemosTheme { ui.theme }
    private var playlist: [LandingGreetingPhrase] { ui.resolvedLandingGreetingPlaylist }
    private var greetingFont: Font {
        AppDisplayTypography.font(size: compact ? 22 : 44)
    }
    /// Font used for the live search line. Shrinks as the query grows so
    /// long prompts still fit on one visual row — mirrors the behaviour of
    /// note titles (a big headline for a short title, smaller for a long
    /// one, then stable below a floor).
    private var searchFont: Font { AppDisplayTypography.font(size: dynamicSearchFontSize) }
    /// Dynamic size curve for the search line. Linear ramp between a soft
    /// threshold (start of shrink) and a hard floor (stable minimum). Animated
    /// via the `.animation(..., value: dynamicSearchFontSize)` binding on
    /// `searchLine` so the transition is smooth rather than steppy.
    private var dynamicSearchFontSize: CGFloat {
        let baseSize: CGFloat = compact ? 22 : 44
        let minSize: CGFloat = compact ? 14 : 18
        let softThreshold = 12
        let hardFloor = 160
        let count = searchText.count
        if count <= softThreshold { return baseSize }
        if count >= hardFloor { return minSize }
        let progress = Double(count - softThreshold) / Double(hardFloor - softThreshold)
        let size = Double(baseSize) - Double(baseSize - minSize) * progress
        return CGFloat(size)
    }
    private var greetingColor: Color {
        theme.fontAccent.opacity(theme.isDark ? 0.94 : 0.9)
    }
    /// Block cursor width/height scaled to the current search font so the
    /// caret stays proportional as the text shrinks.
    private var cursorMetrics: CGSize {
        let size = dynamicSearchFontSize
        return CGSize(width: max(6, size * 0.42), height: max(16, size * 0.9))
    }

    private var shouldAnimate: Bool {
        !ui.windowOccluded && ui.landingGreetingTypewriterEnabled
    }

    private var taskKey: String {
        "\(shouldAnimate)_\(retractNow)_\(searchMode)_\(ui.landingGreetingPlaylistSignature)"
    }

    var body: some View {
        displayView
        .frame(height: compact ? 40 : 180)
        .padding(.horizontal, compact ? 20 : 100)
        .task(id: taskKey) {
            if searchMode {
                await enterSearchMode()
                return
            }
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
        .task(id: searchReady && searchMode) {
            // Cursor blink while the search prompt is active. Cheap — one
            // boolean toggle every ~520ms, gated on searchMode so the task
            // auto-cancels when search mode turns off.
            while !Task.isCancelled && searchReady && searchMode {
                cursorVisible.toggle()
                do {
                    try await Task.sleep(for: LiquidGreetingTiming.cursorBlinkPeriod())
                } catch is CancellationError {
                    return
                } catch {
                    return
                }
            }
        }
    }

    // MARK: - Display

    @ViewBuilder
    private var displayView: some View {
        if searchMode && searchReady {
            searchLine
        } else {
            plainGreeting(text: shouldAnimate ? displayText : Self.restingGreeting)
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

    /// Renders the live query followed by a thick block cursor. When the
    /// query is empty the line is just the cursor — an empty backspaced
    /// greeting with a single blinking caret, ready to receive typed text.
    /// Uses the dynamic `searchFont` that shrinks as the text grows.
    private var searchLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(searchText)
                .font(searchFont)
                .foregroundStyle(greetingColor)
                .lineLimit(3)
                .multilineTextAlignment(.center)
            Rectangle()
                .fill(greetingColor)
                .frame(width: cursorMetrics.width, height: cursorMetrics.height)
                .opacity(cursorVisible ? 1 : 0)
                .padding(.leading, searchText.isEmpty ? 0 : 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .animation(
            reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.82),
            value: dynamicSearchFontSize
        )
        .shadow(
            color: compact ? .clear : (theme.isDark ? theme.fontAccent.opacity(0.12) : .clear),
            radius: compact ? 0 : 8
        )
    }

    // MARK: - Lifecycle helpers

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

    /// Backspace the greeting to empty, then hand off to the caret. The
    /// view flips to `searchLine` once `searchReady = true` — at which
    /// point only the block cursor is visible and any keys the user types
    /// appear as the prompt itself.
    @MainActor
    private func enterSearchMode() async {
        searchReady = false

        // Backspace the current greeting (if any).
        while !displayText.isEmpty && !Task.isCancelled {
            displayText.removeLast()
            guard await pause(LiquidGreetingTiming.retractDelay()) else { return }
        }
        guard !Task.isCancelled else { return }

        // Tiny breath so the empty state registers before the caret
        // starts blinking — makes the morph feel intentional.
        guard await pause(.milliseconds(120)) else { return }

        searchReady = true
        cursorVisible = true
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
