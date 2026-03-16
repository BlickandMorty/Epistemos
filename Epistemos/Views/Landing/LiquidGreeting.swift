import SwiftUI

// MARK: - Liquid Greeting
// Typewriter greeting — RetroGaming font with direct theme-colored text.
//
// Typewriter cycles short prompts: starts with a greeting, then rotates
// through ~30 short 4-5 word prompts. Restarts each time the view becomes active.
//
// Uses .task(id:) for lifecycle — SwiftUI auto-cancels the task when the
// computed `shouldAnimate` flag flips, eliminating manual Task management
// and race conditions during cold launch.

struct LiquidGreeting: View {
    @Environment(UIState.self) private var ui
    nonisolated static let restingGreeting = "welcome back"

    nonisolated static let greetingGlyphPool = Array("·:*+#░▒▓█▄▀▌▐■┐┌┘┴┬╬")
    nonisolated static let greetingRippleConfiguration = ASCIIRippleConfiguration(
        duration: 0.34,
        characters: greetingGlyphPool,
        preserveSpaces: true,
        spread: 1.26,
        waveThreshold: 1.64,
        characterMultiplier: 2,
        animationStep: 0.06,
        waveBuffer: 1.7
    )
    nonisolated static let greetingCharacterDelayRange: ClosedRange<Double> = 28...48
    nonisolated static let greetingPauseRange = 2200...3200
    nonisolated static let greetingShortPauseMilliseconds = 1500
    nonisolated static let greetingInterPhrasePauseRange = 260...380
    nonisolated static let greetingRippleMilestoneStride = 4
    nonisolated static let greetingMorphTransitionInterval = 3
    nonisolated static let greetingMorphFrameDelayRange = 24...42

    nonisolated static func tunedRippleConfiguration(
        intensity: Double,
        variety: Double
    ) -> ASCIIRippleConfiguration {
        let clampedIntensity = max(0, min(1, intensity))
        let clampedVariety = max(0, min(1, variety))
        let minCharacterCount = 6
        let characterCount = min(
            greetingGlyphPool.count,
            max(
                minCharacterCount,
                Int(round(Double(minCharacterCount) + clampedVariety * Double(greetingGlyphPool.count - minCharacterCount)))
            )
        )
        return ASCIIRippleConfiguration(
            duration: 0.28 + (0.12 * clampedIntensity),
            characters: Array(greetingGlyphPool.prefix(characterCount)),
            preserveSpaces: true,
            spread: 0.98 + (0.42 * clampedIntensity),
            waveThreshold: 1.9 - (0.42 * clampedIntensity),
            characterMultiplier: max(1, Int(round(1 + (clampedVariety * 2)))),
            animationStep: 0.07 - (0.02 * clampedIntensity),
            waveBuffer: 1.45 + (0.35 * clampedIntensity)
        )
    }

    nonisolated static func tunedCharacterDelayRange(pace: Double) -> ClosedRange<Double> {
        let clampedPace = max(0, min(1, pace))
        let lowerBound = 22 + (14 * clampedPace)
        let upperBound = 38 + (18 * clampedPace)
        return lowerBound...upperBound
    }

    nonisolated static func tunedPauseRange(pace: Double) -> ClosedRange<Int> {
        let clampedPace = max(0, min(1, pace))
        let lowerBound = Int(round(1500 + (1300 * clampedPace)))
        let upperBound = Int(round(2200 + (1500 * clampedPace)))
        return lowerBound...upperBound
    }

    nonisolated static func tunedShortPauseMilliseconds(pace: Double) -> Int {
        Int(round(1100 + (700 * max(0, min(1, pace)))))
    }

    nonisolated static func tunedInterPhrasePauseRange(pace: Double) -> ClosedRange<Int> {
        let clampedPace = max(0, min(1, pace))
        let lowerBound = Int(round(180 + (120 * clampedPace)))
        let upperBound = Int(round(280 + (140 * clampedPace)))
        return lowerBound...upperBound
    }

    nonisolated static func tunedMorphFrameDelayRange(pace: Double) -> ClosedRange<Int> {
        let clampedPace = max(0, min(1, pace))
        let lowerBound = Int(round(18 + (10 * clampedPace)))
        let upperBound = Int(round(32 + (16 * clampedPace)))
        return lowerBound...upperBound
    }

    nonisolated static func shouldPulseGreetingRipple(atTypedCharacterCount typedCount: Int, totalCount: Int) -> Bool {
        guard typedCount > 0, totalCount > 0 else { return false }
        let clampedCount = min(typedCount, totalCount)
        let initialPulse = min(2, totalCount)
        if clampedCount == initialPulse || clampedCount == totalCount {
            return true
        }
        guard clampedCount > initialPulse else { return false }
        return clampedCount.isMultiple(of: greetingRippleMilestoneStride)
    }

    nonisolated static func shouldMorphGreetingTransition(ordinal: Int, from source: String, to target: String) -> Bool {
        guard ordinal > 0, ordinal.isMultiple(of: greetingMorphTransitionInterval) else { return false }
        guard !source.isEmpty, !target.isEmpty, source != target else { return false }
        return true
    }

    nonisolated static func morphFrames(from source: String, to target: String) -> [String] {
        guard !source.isEmpty, !target.isEmpty, source != target else {
            return target.isEmpty ? [] : [target]
        }

        let targetCharacters = Array(target)
        var working = Array(source)
        var frames: [String] = []
        frames.reserveCapacity(max(working.count, targetCharacters.count))

        for index in 0..<max(working.count, targetCharacters.count) {
            if index < targetCharacters.count {
                if index < working.count {
                    working[index] = targetCharacters[index]
                } else {
                    working.append(targetCharacters[index])
                }
            } else if !working.isEmpty {
                working.removeLast()
            }

            let frame = String(working)
            if frame != source, frame != frames.last, !frame.isEmpty {
                frames.append(frame)
            }
        }

        if frames.last != target {
            frames.append(target)
        }

        return frames
    }

    // Configuration
    var compact: Bool = false
    @Binding var retractNow: Bool
    var onRetractComplete: (() -> Void)? = nil

    @State private var displayText = Self.restingGreeting
    @State private var cursorVisible = true
    @State private var rippleTrigger = 0

    private var theme: EpistemosTheme { ui.theme }
    private var greetingFont: Font { AppDisplayTypography.font(size: compact ? 22 : 44) }
    private var usesSimplifiedGreeting: Bool { ui.displayMode.reducesASCIIAnimations }
    private var greetingAnimationEnabled: Bool { ui.landingGreetingAnimationEnabled }
    private var tunedRippleConfiguration: ASCIIRippleConfiguration {
        Self.tunedRippleConfiguration(
            intensity: ui.landingGreetingIntensity,
            variety: ui.landingGreetingCharacterVariety
        )
    }
    private var tunedCharacterDelayRange: ClosedRange<Double> {
        Self.tunedCharacterDelayRange(pace: ui.landingGreetingPace)
    }
    private var tunedPauseRange: ClosedRange<Int> {
        Self.tunedPauseRange(pace: ui.landingGreetingPace)
    }
    private var tunedShortPauseMilliseconds: Int {
        Self.tunedShortPauseMilliseconds(pace: ui.landingGreetingPace)
    }
    private var tunedInterPhrasePauseRange: ClosedRange<Int> {
        Self.tunedInterPhrasePauseRange(pace: ui.landingGreetingPace)
    }
    private var tunedMorphFrameDelayRange: ClosedRange<Int> {
        Self.tunedMorphFrameDelayRange(pace: ui.landingGreetingPace)
    }

    /// Single reactive flag — drives both typewriter and cursor via .task(id:)
    private var shouldAnimate: Bool {
        ui.activePanel == .home && !ui.windowOccluded && greetingAnimationEnabled
    }

    /// Composite key so .task(id:) restarts when either flag changes
    private var taskKey: String {
        "\(shouldAnimate)_\(retractNow)_\(Int(ui.landingGreetingIntensity * 100))_\(Int(ui.landingGreetingCharacterVariety * 100))_\(Int(ui.landingGreetingPace * 100))"
    }

    // MARK: - Body

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            // Text — directly rendered in theme color, no material masking
            ASCIIRippleText(
                text: displayText,
                font: greetingFont,
                color: theme.fontAccent,
                shadowColor: theme.fontAccent.opacity(0.12),
                shadowRadius: compact ? 0 : 8,
                configuration: tunedRippleConfiguration,
                manualTrigger: rippleTrigger,
                pulseOnAppear: false
            )

            // Block cursor — always present, blinks via Task loop.
            Rectangle()
                .fill(theme.fontAccent.opacity(0.85))
                .frame(width: compact ? 8 : 12, height: compact ? 20 : 36)
                .clipShape(RoundedRectangle(cornerRadius: 2))
                .opacity(!usesSimplifiedGreeting && cursorVisible ? 1 : 0)
                .animation(.easeInOut(duration: 0.3), value: cursorVisible)
                .padding(.leading, 2)
        }
        .frame(minHeight: compact ? 0 : 80)
        .shadow(color: compact ? .clear : theme.fontAccent.opacity(0.12), radius: compact ? 0 : 8)
        // Single reactive task — SwiftUI cancels + restarts when taskKey changes.
        // No manual onAppear/onDisappear/onChange juggling needed.
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
            if usesSimplifiedGreeting {
                cursorVisible = false
                displayText = Self.restingGreeting
                return
            }
            // Small yield so SwiftUI's initial layout pass finishes before we
            // start mutating @State on every keystroke.
            try? await Task.sleep(for: .milliseconds(50))
            guard !Task.isCancelled else { return }

            // Launch cursor blink as a detached child — cancelled automatically
            // when the .task(id:) is cancelled by SwiftUI.
            let blinkTask = Task { @MainActor in
                await cursorBlinkLoop()
            }
            await typewriterLoop()
            blinkTask.cancel()
        }
    }

    // MARK: - Cursor Blink

    @MainActor
    private func cursorBlinkLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            cursorVisible.toggle()
        }
    }

    // MARK: - Retract

    @MainActor
    private func retractText() async {
        guard !displayText.isEmpty else { return }
        while !displayText.isEmpty && !Task.isCancelled {
            displayText.removeLast()
            try? await Task.sleep(for: .milliseconds(15))
        }
        guard !Task.isCancelled else { return }
        onRetractComplete?()
    }

    // MARK: - Typewriter Engine
    // Simple cycle: random greeting → short prompts → loop.
    // Resets to a fresh greeting each time the task restarts.

    @MainActor
    private func typewriterLoop() async {
        // === NORMAL GREETING LOOP ===
        var currentPhrase = ShortPrompts.greetings.randomElement() ?? "Greetings, Researcher"
        var transitionOrdinal = 0

        while !Task.isCancelled {
            if displayText != currentPhrase {
                await typePhrase(currentPhrase)
                guard !Task.isCancelled else { return }
            }

            let pauseTime = currentPhrase.count < 8
                ? tunedShortPauseMilliseconds
                : Int.random(in: tunedPauseRange)
            try? await Task.sleep(for: .milliseconds(pauseTime))
            guard !Task.isCancelled else { return }

            let nextPhrase = ShortPrompts.pickRandom(excluding: currentPhrase)
            transitionOrdinal += 1

            if Self.shouldMorphGreetingTransition(ordinal: transitionOrdinal, from: currentPhrase, to: nextPhrase) {
                await morphPhrase(from: currentPhrase, to: nextPhrase)
                guard !Task.isCancelled else { return }
            } else {
                await untypePhrase(currentPhrase)
                guard !Task.isCancelled else { return }
                try? await Task.sleep(for: .milliseconds(Int.random(in: tunedInterPhrasePauseRange)))
                guard !Task.isCancelled else { return }
            }

            currentPhrase = nextPhrase
        }
    }

    @MainActor
    private func typePhrase(_ phrase: String) async {
        for i in 1...phrase.count {
            guard !Task.isCancelled else { return }
            displayText = String(phrase.prefix(i))
            if Self.shouldPulseGreetingRipple(atTypedCharacterCount: i, totalCount: phrase.count) {
                triggerGreetingRipple()
            }

            let ch = displayText.last ?? " "
            var delay: Double = Double.random(in: tunedCharacterDelayRange)

            if ".!?".contains(ch) { delay += Double.random(in: 80...160) }
            else if ",;:".contains(ch) { delay += Double.random(in: 40...90) }
            else if ch == " " && Double.random(in: 0...1) < 0.05 { delay += Double.random(in: 30...70) }

            if Double.random(in: 0...1) < 0.04 { delay += Double.random(in: 60...120) }
            if Double.random(in: 0...1) < 0.01 { delay += Double.random(in: 120...220) }

            if i <= 2 { delay += 40 }

            try? await Task.sleep(for: .milliseconds(Int(delay)))
        }
    }

    @MainActor
    private func untypePhrase(_ phrase: String) async {
        var charIdx = phrase.count
        try? await Task.sleep(for: .milliseconds(40))
        while charIdx > 0 && !Task.isCancelled {
            let progress = 1.0 - Double(charIdx) / Double(phrase.count)
            let deleteSpeed = max(6, 18 - Int(progress * 12))
            let charsToDelete = charIdx > 10 ? min(charIdx, 1 + Int.random(in: 0...1)) : 1
            charIdx = max(0, charIdx - charsToDelete)
            displayText = String(phrase.prefix(charIdx))
            try? await Task.sleep(for: .milliseconds(deleteSpeed))
        }
    }

    @MainActor
    private func morphPhrase(from source: String, to target: String) async {
        for frame in Self.morphFrames(from: source, to: target) {
            guard !Task.isCancelled else { return }
            displayText = frame
            triggerGreetingRipple()
            try? await Task.sleep(for: .milliseconds(Int.random(in: tunedMorphFrameDelayRange)))
        }
    }

    @MainActor
    private func triggerGreetingRipple() {
        guard !usesSimplifiedGreeting, !displayText.isEmpty else { return }
        rippleTrigger += 1
    }
}

// MARK: - Short Prompts
// Compact prompt bank — greetings + ~30 short (4-5 word) prompts.

private enum ShortPrompts {
    static let greetings: [String] = [
        "Greetings, Researcher",
        "Sup, Brainiac!",
    ]

    static let prompts: [String] = [
        "what's on your mind?",
        "got a burning question?",
        "ready when you are",
        "let's figure it out",
        "curiosity starts here",
        "ask me literally anything",
        "thinking caps on?",
        "what are we exploring?",
        "fire away, chief",
        "big thoughts? small ones?",
        "research mode: activated",
        "your move, scientist",
        "discovery awaits you",
        "go on, surprise me",
        "the rabbit hole awaits",
        "knowledge is power, etc.",
        "let's learn something new",
        "overthinking? let's simplify.",
        "feed me a question",
        "answers are overrated. ask.",
        "the truth is out there",
        "what keeps you up?",
        "ideas need poking, go.",
        "science never sleeps",
        "ask the hard one",
        "nothing's off-limits here",
        "question everything, always",
        "start with why",
        "no such thing as dumb",
        "brains beat brawn, always",
    ]

    static let all: [String] = greetings + prompts

    static func pickRandom(excluding: String) -> String {
        guard prompts.count > 1 else { return prompts.first ?? "" }
        var pick: String
        repeat {
            pick = prompts.randomElement() ?? ""
        } while pick == excluding
        return pick
    }
}
