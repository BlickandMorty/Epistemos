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
    @Environment(VaultSyncService.self) private var vaultSync

    // Configuration
    var compact: Bool = false
    @Binding var retractNow: Bool
    var onRetractComplete: (() -> Void)? = nil

    // Typewriter state — pre-fill with a vault sync message if import will start on launch.
    @State private var displayText: String = {
        UserDefaults.standard.data(forKey: "epistemos.vaultBookmark") != nil ? "syncing vault..." : ""
    }()
    @State private var cursorVisible = true

    private var theme: EpistemosTheme { ui.theme }
    private var greetingFont: Font { AppDisplayTypography.font(size: compact ? 22 : 44) }
    private var usesSimplifiedGreeting: Bool { ui.displayMode.reducesASCIIAnimations }

    /// Single reactive flag — drives both typewriter and cursor via .task(id:)
    private var shouldAnimate: Bool {
        ui.activePanel == .home && !ui.windowOccluded
    }

    /// Composite key so .task(id:) restarts when either flag changes
    private var taskKey: String {
        "\(shouldAnimate)_\(retractNow)"
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
                shadowRadius: compact ? 0 : 8
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
                displayText = ""
                cursorVisible = false
                return
            }
            if usesSimplifiedGreeting {
                cursorVisible = false
                displayText = vaultSync.isIndexing ? "syncing vault..." : "welcome back"
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
        // === VAULT SYNC PHASE ===
        // displayText is pre-filled with "syncing vault..." from init if a vault
        // bookmark exists, so it's visible on the very first frame.
        // Just hold until the vault sync finishes, then untype.
        if vaultSync.isIndexing {
            displayText = "syncing vault..."

            while vaultSync.isIndexing && !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(200))
            }
            guard !Task.isCancelled else { return }

            try? await Task.sleep(for: .milliseconds(400))
            await untypePhrase("syncing vault...")
            guard !Task.isCancelled else { return }
            try? await Task.sleep(for: .milliseconds(300))
        }

        // === NORMAL GREETING LOOP ===
        var lastPhrase = ""
        var currentPhrase = ShortPrompts.greetings.randomElement() ?? "Greetings, Researcher"

        while !Task.isCancelled {
            await typePhrase(currentPhrase)
            guard !Task.isCancelled else { return }

            let pauseTime = currentPhrase.count < 8 ? 1200 : Int.random(in: 2400...3200)
            try? await Task.sleep(for: .milliseconds(pauseTime))
            guard !Task.isCancelled else { return }

            await untypePhrase(currentPhrase)
            guard !Task.isCancelled else { return }

            try? await Task.sleep(for: .milliseconds(Int.random(in: 300...500)))

            currentPhrase = ShortPrompts.pickRandom(excluding: lastPhrase)
            lastPhrase = currentPhrase
        }
    }

    @MainActor
    private func typePhrase(_ phrase: String) async {
        for i in 1...phrase.count {
            guard !Task.isCancelled else { return }
            displayText = String(phrase.prefix(i))

            let ch = displayText.last ?? " "
            var delay: Double = Double.random(in: 45...75)

            if ".!?".contains(ch) { delay += Double.random(in: 200...400) }
            else if ",;:".contains(ch) { delay += Double.random(in: 80...160) }
            else if ch == " " && Double.random(in: 0...1) < 0.08 { delay += Double.random(in: 60...120) }

            if Double.random(in: 0...1) < 0.10 { delay += Double.random(in: 120...250) }
            if Double.random(in: 0...1) < 0.03 { delay += Double.random(in: 350...600) }

            if i <= 2 { delay += 100 }

            try? await Task.sleep(for: .milliseconds(Int(delay)))
        }
    }

    @MainActor
    private func untypePhrase(_ phrase: String) async {
        var charIdx = phrase.count
        try? await Task.sleep(for: .milliseconds(80))
        while charIdx > 0 && !Task.isCancelled {
            let progress = 1.0 - Double(charIdx) / Double(phrase.count)
            let deleteSpeed = max(8, 28 - Int(progress * 20))
            let charsToDelete = charIdx > 10 ? min(charIdx, 1 + Int.random(in: 0...1)) : 1
            charIdx = max(0, charIdx - charsToDelete)
            displayText = String(phrase.prefix(charIdx))
            try? await Task.sleep(for: .milliseconds(deleteSpeed))
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
