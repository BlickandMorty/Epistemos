import SwiftUI

enum LiquidGreetingTiming {
    nonisolated static func startupDelay() -> Duration { .milliseconds(50) }
    nonisolated static func retractDelay() -> Duration { .milliseconds(15) }
    nonisolated static func holdDelay(for phrase: LandingGreetingPhrase) -> Duration { .seconds(phrase.durationSeconds) }
    nonisolated static func transitionDelay() -> Duration { .milliseconds(320) }
    /// Pause between the "Greetings," line completing and the
    /// "Researcher" line starting to type. Gives the stacked greeting
    /// a beat of breathing room so the second line reads as a follow-
    /// on, not part of the same typing pass.
    nonisolated static func researcherLineDelay() -> Duration { .milliseconds(280) }
    /// Pause between the "Researcher" line completing and the rotating
    /// phrases starting. Holds the full greeting onscreen briefly so
    /// the user reads it before the phrase loop begins.
    nonisolated static func phrasesStartDelay() -> Duration { .milliseconds(420) }

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

// MARK: - LiquidGreeting (stacked layout 2026-05-13)
//
// Renders the landing-page greeting as three stacked typewriter lines:
//   1. "Greetings,"  (hero font, theme-resolved)
//   2. "Researcher"  (hero font, theme-resolved)
//   3. Rotating phrases (smaller font: coral on light, JetBrainsMono
//      on dark) typing out below the greeting and above the commands.
//
// Per user direction 2026-05-13:
//   - Hero size reduced (was 62pt, "huge"; now sits at 44pt expanded /
//     22pt compact so it has presence without dominating the page).
//   - Stacked greeting + smaller continuous phrase rail.
//   - Light-mode hero font picked per ThemePair (Platinum →
//     MatrixTypeDisplay-Regular, Classic → ColorBasic-Regular,
//     Ember → RetroByte). Dark mode keeps RetroGaming everywhere.
//   - Phrases use CoralPixels in light mode (all themes), JetBrainsMono
//     in dark mode.

struct LiquidGreeting: View {
    nonisolated static let greetingLine1 = "Greetings,"
    nonisolated static let greetingLine2 = "Researcher"
    /// Back-compat alias for callers that previously referenced the
    /// single-line greeting. Most call sites pre-2026-05-13 used this
    /// to seed `LandingGreetingPhrase` playlists; the new stacked
    /// layout publishes the same string via `greetingLine1 + " " +
    /// greetingLine2` so search snapshots / accessibility readers
    /// still get the full label.
    nonisolated static let restingGreeting = "\(greetingLine1) \(greetingLine2)"

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

    /// Live first-line content. Empty during pre-typing, fills as the
    /// "Greetings," text types out, stays full while line 2 + phrases
    /// run, gets backspaced when search mode activates or retract
    /// fires.
    @State private var line1: String = ""
    /// Same shape for the second line.
    @State private var line2: String = ""
    /// Live rotating-phrase text. Independent typewriter loop driven
    /// by `runPhraseLoop()` once both greeting lines are filled.
    @State private var phraseText: String = ""
    @State private var searchReady: Bool = false
    @State private var cursorVisible: Bool = true

    private var theme: EpistemosTheme { ui.theme }
    private var playlist: [LandingGreetingPhrase] { ui.resolvedLandingGreetingPlaylist }

    /// Hero font for the two stacked greeting lines. Theme-resolved
    /// (Platinum → MatrixTypeDisplay, Classic → Color Basic, Ember →
    /// RetroByte; dark mode → RetroGaming for all). Sized smaller
    /// than the previous single-line 62pt hero per user direction.
    private var heroFont: Font {
        let size: CGFloat = compact ? 22 : 44
        return Font.custom(theme.displayFontName, size: size)
    }

    /// Smaller font for the rotating phrases. Light mode = coral
    /// pixel (CoralPixels-Regular) regardless of theme; dark mode =
    /// JetBrainsMono (the "chat monospace font" per user direction).
    private var phraseFont: Font {
        let size: CGFloat = compact ? 13 : 18
        let name = theme.isDark
            ? AppDisplayTypography.monoFontName
            : AppDisplayTypography.coralDisplayFontName
        return Font.custom(name, size: size)
    }

    /// Search-line font shrinks as the query grows — same dynamic
    /// curve as before, but anchored to the new smaller hero baseline.
    private var searchFont: Font {
        Font.custom(theme.displayFontName, size: dynamicSearchFontSize)
    }
    private var dynamicSearchFontSize: CGFloat {
        let baseSize: CGFloat = compact ? 22 : 36
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
    /// Phrases get a quieter color than the hero — secondary so the
    /// eye lands on the greeting first.
    private var phraseColor: Color {
        theme.fontAccent.opacity(theme.isDark ? 0.70 : 0.66)
    }

    /// Block cursor metrics scaled to the current search font.
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
        .frame(maxHeight: compact ? 80 : 220)
        .padding(.horizontal, compact ? 20 : 60)
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
                line1 = Self.greetingLine1
                line2 = Self.greetingLine2
                phraseText = ""
                return
            }
            line1 = ""
            line2 = ""
            phraseText = ""
            guard await pause(LiquidGreetingTiming.startupDelay()) else { return }
            await typeIntoLine(Self.greetingLine1, lineIndex: 1)
            guard !Task.isCancelled else { return }
            guard await pause(LiquidGreetingTiming.researcherLineDelay()) else { return }
            await typeIntoLine(Self.greetingLine2, lineIndex: 2)
            guard !Task.isCancelled else { return }
            guard await pause(LiquidGreetingTiming.phrasesStartDelay()) else { return }
            await runPhraseLoop()
        }
        .task(id: searchReady && searchMode) {
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
            stackedGreeting
        }
    }

    /// Apply Classic-theme uppercase if the active theme prefers it.
    /// ChonkyPixels reads best ALL-CAPS per user direction 2026-05-13;
    /// other themes keep mixed case (Platinum + Ember). The transform
    /// is applied at render time so the typewriter state stays in
    /// canonical mixed-case (which keeps timing, backspace, and
    /// shared-prefix calculations correct).
    private func displayCased(_ text: String) -> String {
        theme.prefersUppercaseDisplay ? text.uppercased() : text
    }

    /// Two-line stacked greeting with rotating phrases below. Each line
    /// gets its own typewriter so the user sees "Greetings," appear,
    /// pause, then "Researcher" arrive on its own row.
    private var stackedGreeting: some View {
        VStack(alignment: .center, spacing: compact ? 2 : 4) {
            Text(displayCased(line1))
                .font(heroFont)
                .foregroundStyle(greetingColor)
                .lineLimit(1)
            Text(displayCased(line2))
                .font(heroFont)
                .foregroundStyle(greetingColor)
                .lineLimit(1)
            if !phraseText.isEmpty || shouldAnimate {
                Text(phraseText)
                    .font(phraseFont)
                    .foregroundStyle(phraseColor)
                    .lineLimit(1)
                    .padding(.top, compact ? 4 : 10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .shadow(
            color: compact
                ? .clear
                : (theme.isDark
                    ? theme.fontAccent.opacity(0.12)
                    : (theme.headingGlows
                        ? theme.fontAccent.opacity(0.18)
                        : Color.black.opacity(0.06))),
            radius: compact ? 0 : (theme.isDark ? 8 : (theme.headingGlows ? 6 : 5))
        )
    }

    /// Renders the live query followed by a thick block cursor.
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
            color: compact
                ? .clear
                : (theme.isDark
                    ? theme.fontAccent.opacity(0.12)
                    : Color.black.opacity(0.08)),
            radius: compact ? 0 : (theme.isDark ? 8 : 5)
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
        // Backspace phrases first (smaller surface, fastest disappear),
        // then line 2, then line 1.
        while !phraseText.isEmpty && !Task.isCancelled {
            phraseText.removeLast()
            guard await pause(LiquidGreetingTiming.retractDelay()) else { return }
        }
        while !line2.isEmpty && !Task.isCancelled {
            line2.removeLast()
            guard await pause(LiquidGreetingTiming.retractDelay()) else { return }
        }
        while !line1.isEmpty && !Task.isCancelled {
            line1.removeLast()
            guard await pause(LiquidGreetingTiming.retractDelay()) else { return }
        }
        guard !Task.isCancelled else { return }
        onRetractComplete?()
    }

    @MainActor
    private func enterSearchMode() async {
        searchReady = false
        // Backspace every line in reverse order so the morph reads as
        // a unified retraction rather than three races.
        while !phraseText.isEmpty && !Task.isCancelled {
            phraseText.removeLast()
            guard await pause(LiquidGreetingTiming.retractDelay()) else { return }
        }
        while !line2.isEmpty && !Task.isCancelled {
            line2.removeLast()
            guard await pause(LiquidGreetingTiming.retractDelay()) else { return }
        }
        while !line1.isEmpty && !Task.isCancelled {
            line1.removeLast()
            guard await pause(LiquidGreetingTiming.retractDelay()) else { return }
        }
        guard !Task.isCancelled else { return }
        guard await pause(.milliseconds(120)) else { return }
        searchReady = true
        cursorVisible = true
    }

    /// Type characters into one of the two greeting lines.
    @MainActor
    private func typeIntoLine(_ phrase: String, lineIndex: Int) async {
        guard !phrase.isEmpty else { return }
        for index in 1...phrase.count {
            guard !Task.isCancelled else { return }
            let prefix = String(phrase.prefix(index))
            switch lineIndex {
            case 1: line1 = prefix
            case 2: line2 = prefix
            default: break
            }
            guard await pause(LiquidGreetingTiming.typingDelay(forStep: index)) else { return }
        }
    }

    /// Rotating-phrase loop. Cycles through the playlist, typing each
    /// phrase character-by-character into the smaller phrase rail
    /// below the greeting. Backspaces between phrases share-prefix-
    /// aware so adjacent phrases morph rather than fully clearing.
    @MainActor
    private func runPhraseLoop() async {
        let activePlaylist = playlist
        guard !activePlaylist.isEmpty else { return }
        var phraseIndex = 0
        while !Task.isCancelled {
            let current = activePlaylist[phraseIndex]
            let next = activePlaylist[(phraseIndex + 1) % activePlaylist.count]
            let keepFrom = sharedPrefixLength(phraseText, current.text)
            await typeIntoPhraseFrom(current.text, startAt: keepFrom)
            guard !Task.isCancelled else { return }
            guard await pause(LiquidGreetingTiming.holdDelay(for: current)) else { return }
            let keepTo = sharedPrefixLength(current.text, next.text)
            await untypePhraseTo(current.text, stopAt: keepTo)
            guard !Task.isCancelled else { return }
            guard await pause(LiquidGreetingTiming.transitionDelay()) else { return }
            phraseIndex = (phraseIndex + 1) % activePlaylist.count
        }
    }

    private func sharedPrefixLength(_ a: String, _ b: String) -> Int {
        var count = 0
        for (ca, cb) in zip(a, b) {
            guard ca == cb else { break }
            count += 1
        }
        return count
    }

    @MainActor
    private func typeIntoPhraseFrom(_ phrase: String, startAt: Int) async {
        guard !phrase.isEmpty else {
            phraseText = ""
            return
        }
        let start = max(startAt, 0)
        guard start < phrase.count else {
            phraseText = phrase
            return
        }
        if start == 0 { phraseText = "" }
        for index in (start + 1)...phrase.count {
            guard !Task.isCancelled else { return }
            phraseText = String(phrase.prefix(index))
            guard await pause(LiquidGreetingTiming.typingDelay(forStep: index)) else { return }
        }
    }

    @MainActor
    private func untypePhraseTo(_ phrase: String, stopAt: Int) async {
        var index = phrase.count
        let floor = max(stopAt, 0)
        while index > floor && !Task.isCancelled {
            index -= 1
            phraseText = String(phrase.prefix(index))
            guard await pause(LiquidGreetingTiming.untypingDelay(forStep: index)) else { return }
        }
    }
}
