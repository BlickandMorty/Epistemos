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

    // Typewriter state
    @State private var displayText = ""
    @State private var cursorVisible = true

    private var theme: EpistemosTheme { ui.theme }
    private var greetingFont: Font { .custom("RetroGaming", size: 44) }

    /// Single reactive flag — drives both typewriter and cursor via .task(id:)
    private var shouldAnimate: Bool {
        ui.activePanel == .home && !ui.windowOccluded
    }

    // MARK: - Body

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            // Text — directly rendered in theme color, no material masking
            Text(displayText)
                .font(greetingFont)
                .foregroundStyle(theme.fontAccent)
                .fixedSize(horizontal: true, vertical: true)

            // Block cursor — always present, blinks via Task loop.
            Rectangle()
                .fill(theme.fontAccent.opacity(0.85))
                .frame(width: 12, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 2))
                .opacity(cursorVisible ? 1 : 0)
                .animation(.easeInOut(duration: 0.3), value: cursorVisible)
                .padding(.leading, 2)
        }
        .frame(minHeight: 80) // Prevent collapse when displayText is empty
        .shadow(color: theme.fontAccent.opacity(0.12), radius: 8)
        // Single reactive task — SwiftUI cancels + restarts when shouldAnimate changes.
        // No manual onAppear/onDisappear/onChange juggling needed.
        .task(id: shouldAnimate) {
            guard shouldAnimate else {
                displayText = ""
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

    // MARK: - Typewriter Engine
    // Simple cycle: random greeting → short prompts → loop.
    // Resets to a fresh greeting each time the task restarts.

    @MainActor
    private func typewriterLoop() async {
        var lastPhrase = ""
        var currentPhrase = ShortPrompts.greetings.randomElement() ?? "Greetings, Researcher"

        while !Task.isCancelled {
            // === TYPE ===
            for i in 1...currentPhrase.count {
                guard !Task.isCancelled else { return }
                displayText = String(currentPhrase.prefix(i))

                let ch = displayText.last ?? " "
                var delay: Double = Double.random(in: 45...75)

                if ".!?".contains(ch) { delay += Double.random(in: 200...400) }
                else if ",;:".contains(ch) { delay += Double.random(in: 80...160) }
                else if ch == " " && Double.random(in: 0...1) < 0.08 { delay += Double.random(in: 60...120) }

                // Natural stutter
                if Double.random(in: 0...1) < 0.10 { delay += Double.random(in: 120...250) }
                if Double.random(in: 0...1) < 0.03 { delay += Double.random(in: 350...600) }

                if i <= 2 { delay += 100 }

                try? await Task.sleep(for: .milliseconds(Int(delay)))
            }

            // === PAUSE ===
            let pauseTime = currentPhrase.count < 8 ? 1200 : Int.random(in: 2400...3200)
            try? await Task.sleep(for: .milliseconds(pauseTime))

            // === DELETE ===
            var charIdx = currentPhrase.count
            try? await Task.sleep(for: .milliseconds(80))
            while charIdx > 0 && !Task.isCancelled {
                let progress = 1.0 - Double(charIdx) / Double(currentPhrase.count)
                let deleteSpeed = max(8, 28 - Int(progress * 20))
                let charsToDelete = charIdx > 10 ? min(charIdx, 1 + Int.random(in: 0...1)) : 1
                charIdx = max(0, charIdx - charsToDelete)
                displayText = String(currentPhrase.prefix(charIdx))
                try? await Task.sleep(for: .milliseconds(deleteSpeed))
            }

            // === PICK NEXT ===
            try? await Task.sleep(for: .milliseconds(Int.random(in: 300...500)))

            // Pick from short prompts, avoiding repeat
            currentPhrase = ShortPrompts.pickRandom(excluding: lastPhrase)
            lastPhrase = currentPhrase
        }
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
