import SwiftUI

enum LiquidGreetingTiming {
    nonisolated static func startupDelay() -> Duration { .milliseconds(50) }
    nonisolated static func retractDelay() -> Duration { .milliseconds(15) }
    nonisolated static func holdDelay(for phrase: LandingGreetingPhrase) -> Duration { .seconds(phrase.durationSeconds) }
    nonisolated static func transitionDelay() -> Duration { .milliseconds(320) }
    /// Pause between line 1 of a hero pair completing and line 2
    /// starting to type. Gives the stacked layout a beat of breathing
    /// room so line 2 reads as a follow-on, not part of the same
    /// typing pass.
    nonisolated static func researcherLineDelay() -> Duration { .milliseconds(280) }
    /// Hold the fully-typed stacked hero on screen between pairs.
    /// Long enough to read the two lines comfortably without feeling
    /// stuck. 2026-05-13 third pass — replaces the phrase-rail
    /// `holdDelay(for:)` per-phrase duration since every hero pair
    /// holds for the same length now.
    nonisolated static func heroHoldDelay() -> Duration { .milliseconds(2600) }
    /// Legacy alias for `heroHoldDelay`. Kept so any out-of-tree caller
    /// referencing `phrasesStartDelay` continues to compile.
    nonisolated static func phrasesStartDelay() -> Duration { heroHoldDelay() }

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

// MARK: - LiquidGreeting (hero-only loop 2026-05-13 third pass)
//
// Per user direction 2026-05-13 (third pass): the smaller rotating
// phrase rail underneath the hero is REMOVED. The landing greeting now
// loops two stacked hero pairs:
//   1. "Greetings,"  /  "Researcher"
//   2. "Click anywhere"  /  "to start a conversation"
// Both pairs render in the hero font + size — no separate smaller
// font. The hero typewriter cycles: types pair 1, holds, backspaces,
// types pair 2, holds, backspaces, repeats. Each theme's hero font
// (Classic → CoralPixels, Platinum → MatrixTypeDisplay, Ember →
// DotempDemo-8bit) applies to BOTH pairs.

struct LiquidGreeting: View {
    /// Stacked hero pair — both lines render in the hero font + size.
    nonisolated struct HeroPair: Equatable, Sendable {
        let line1: String
        let line2: String
    }

    nonisolated static let greetingPair = HeroPair(line1: "Greetings,", line2: "Researcher")
    nonisolated static let promptPair = HeroPair(line1: "Click anywhere", line2: "to start a conversation")
    nonisolated static let heroPairs: [HeroPair] = [greetingPair, promptPair]

    nonisolated static let greetingLine1 = greetingPair.line1
    nonisolated static let greetingLine2 = greetingPair.line2
    /// Back-compat alias for callers that previously referenced the
    /// single-line greeting.
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

    /// Live first-line content for the active hero pair. Empty during
    /// pre-typing, fills as `pair.line1` types out, gets backspaced
    /// during the inter-pair transition.
    @State private var line1: String = ""
    /// Same shape for the second line.
    @State private var line2: String = ""
    @State private var searchReady: Bool = false
    @State private var cursorVisible: Bool = true

    private var theme: EpistemosTheme { ui.theme }

    /// Hero font for the two stacked lines. Theme-resolved: Classic →
    /// CoralPixels, Platinum → MatrixTypeDisplay, Ember →
    /// ColorBasic-Regular. Both light + dark modes share the same face
    /// on each theme.
    ///
    /// 2026-05-13 fifth pass: Classic gets a slight size bump per user
    /// direction ("increase the size of the greeting on the classic
    /// mode a little"). CoralPixels has a higher x-height than
    /// MatrixType/ColorBasic so the same point size reads as smaller —
    /// bumping ~14% closes the perceptual gap.
    private var heroFont: Font {
        let baseSize: CGFloat = compact ? 22 : 44
        let size: CGFloat = theme.themePair == .classic
            ? baseSize * 1.14
            : baseSize
        return Font.custom(theme.displayFontName, size: size)
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

    /// Block cursor metrics scaled to the current search font.
    private var cursorMetrics: CGSize {
        let size = dynamicSearchFontSize
        return CGSize(width: max(6, size * 0.42), height: max(16, size * 0.9))
    }

    private var shouldAnimate: Bool {
        !ui.windowOccluded && ui.landingGreetingTypewriterEnabled
    }

    private var taskKey: String {
        "\(shouldAnimate)_\(retractNow)_\(searchMode)"
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
                return
            }
            line1 = ""
            line2 = ""
            guard await pause(LiquidGreetingTiming.startupDelay()) else { return }
            // 2026-05-13 third pass: loop the two stacked hero pairs
            // (Greetings/Researcher ↔ Click anywhere/to start a
            // conversation). No smaller-font phrase rail underneath.
            await runHeroLoop()
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

    /// Two-line stacked hero. Each line gets its own typewriter so the
    /// user sees `pair.line1` appear, pause, then `pair.line2` arrive
    /// on its own row. Both lines render in the hero font + size; the
    /// smaller-font phrase rail underneath was removed 2026-05-13
    /// (third pass) per user direction.
    ///
    /// 2026-05-13 fifth pass: on Ember, `line1` is rendered in the
    /// plain (no-box) glyph form via `plainLabelText` (uppercases the
    /// text so ColorBasic's A-Z glyphs render) and `line2` is rendered
    /// in the boxed form via `boxedLabelText` (lowercases so a-z
    /// renders as white-on-black). Other themes pass through unchanged.
    private var stackedGreeting: some View {
        VStack(alignment: .center, spacing: compact ? 2 : 4) {
            Text(theme.plainLabelText(line1))
                .font(heroFont)
                .foregroundStyle(greetingColor)
                .lineLimit(1)
            Text(theme.boxedLabelText(line2))
                .font(heroFont)
                .foregroundStyle(greetingColor)
                .lineLimit(1)
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
        // Backspace line 2 first, then line 1. (The smaller phrase
        // rail was removed 2026-05-13 third pass.)
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
        // Backspace both lines in reverse order so the morph reads as
        // a unified retraction.
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

    /// Stacked-hero loop. Cycles through the `heroPairs` list (greeting
    /// → click-anywhere → greeting → …), typing each pair in line1 +
    /// line2 stacked, holding, then backspacing both lines before the
    /// next pair lands. Replaces the previous smaller-font phrase rail.
    ///
    /// Hold duration is fixed at 2.6 s per pair — long enough to read
    /// without feeling stuck. Backspace runs line 2 → line 1 (matches
    /// `retractText`) so the user sees the pair retract from the
    /// bottom up.
    @MainActor
    private func runHeroLoop() async {
        let pairs = Self.heroPairs
        guard !pairs.isEmpty else { return }
        var index = 0
        while !Task.isCancelled {
            let pair = pairs[index]
            await typeIntoLine(pair.line1, lineIndex: 1)
            guard !Task.isCancelled else { return }
            guard await pause(LiquidGreetingTiming.researcherLineDelay()) else { return }
            await typeIntoLine(pair.line2, lineIndex: 2)
            guard !Task.isCancelled else { return }
            guard await pause(LiquidGreetingTiming.heroHoldDelay()) else { return }
            await backspaceLine(lineIndex: 2)
            guard !Task.isCancelled else { return }
            await backspaceLine(lineIndex: 1)
            guard !Task.isCancelled else { return }
            guard await pause(LiquidGreetingTiming.transitionDelay()) else { return }
            index = (index + 1) % pairs.count
        }
    }

    /// Backspace one of the two hero lines character-by-character. Uses
    /// the same per-step cadence as the existing `untypingDelay` so the
    /// retraction reads at the same speed as the (retired) phrase
    /// rail's untype path.
    @MainActor
    private func backspaceLine(lineIndex: Int) async {
        switch lineIndex {
        case 1:
            while !line1.isEmpty && !Task.isCancelled {
                let nextLen = line1.count
                line1.removeLast()
                guard await pause(LiquidGreetingTiming.untypingDelay(forStep: nextLen)) else { return }
            }
        case 2:
            while !line2.isEmpty && !Task.isCancelled {
                let nextLen = line2.count
                line2.removeLast()
                guard await pause(LiquidGreetingTiming.untypingDelay(forStep: nextLen)) else { return }
            }
        default:
            return
        }
    }
}
