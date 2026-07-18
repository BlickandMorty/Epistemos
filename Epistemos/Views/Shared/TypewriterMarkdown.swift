import SwiftUI
import AppKit

// MARK: - Typewriter Plain Text
// Progressive reveal for plain text welcome and session views.
// Uses LocalizedStringKey for markdown-lite rendering (bold, italic).

struct TypewriterPlainText: View {
    let content: String
    var slowRate: Int = 2
    var mediumRate: Int = 8
    var fastRate: Int = 25

    @State private var revealedCount = 0
    @State private var isComplete = false

    var body: some View {
        Text(LocalizedStringKey(String(content.prefix(isComplete ? content.count : revealedCount))))
            .task(id: content) {
                guard !content.isEmpty else { return }
                revealedCount = 0
                isComplete = false

                let haptic = NSHapticFeedbackManager.defaultPerformer
                var tickCount = 0
                var lastHapticAt = 0

                while revealedCount < content.count && !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(16))
                    tickCount += 1

                    let rate: Int
                    if tickCount < 15 {
                        rate = slowRate
                    } else if tickCount < 60 {
                        rate = mediumRate
                    } else {
                        rate = fastRate
                    }

                    revealedCount = min(revealedCount + rate, content.count)

                    if revealedCount - lastHapticAt >= 40 {
                        haptic.perform(.alignment, performanceTime: .now)
                        lastHapticAt = revealedCount
                    }
                }

                isComplete = true
            }
    }
}

// MARK: - Haptic Helpers
// Fire-and-forget haptic pulse — used by streaming token flushes
// to give subtle feedback as tokens arrive.

enum HomeCommandHapticStyle: Sendable {
    case search
    case capture
    case workspace
    case save
    case timeMachine
    case notes
    case newNote
    case document
    case graph
    case agent
}

enum HapticHelper {
    @MainActor
    private static func perform(_ pattern: NSHapticFeedbackManager.FeedbackPattern) {
        NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .now)
    }

    @MainActor
    private static func performDelayed(
        _ pattern: NSHapticFeedbackManager.FeedbackPattern,
        after delay: Duration
    ) {
        Task { @MainActor in
            do {
                try await Task.sleep(for: delay)
            } catch {
                return
            }
            perform(pattern)
        }
    }

    @MainActor
    static func softTick() {
        perform(.alignment)
    }

    @MainActor
    static func sidebarHoverTick() {
        perform(.generic)
    }

    @MainActor
    static func softPump() {
        perform(.levelChange)
    }

    @MainActor
    static func homeCommand(_ style: HomeCommandHapticStyle) {
        switch style {
        case .search:
            perform(.alignment)
            performDelayed(.levelChange, after: .milliseconds(70))
        case .capture:
            perform(.generic)
        case .workspace:
            perform(.levelChange)
        case .save:
            perform(.alignment)
            performDelayed(.alignment, after: .milliseconds(55))
        case .timeMachine:
            perform(.levelChange)
            performDelayed(.generic, after: .milliseconds(80))
        case .notes:
            perform(.generic)
        case .newNote:
            perform(.alignment)
        case .document:
            perform(.levelChange)
            performDelayed(.alignment, after: .milliseconds(65))
        case .graph:
            perform(.levelChange)
            performDelayed(.levelChange, after: .milliseconds(75))
        case .agent:
            perform(.alignment)
            performDelayed(.generic, after: .milliseconds(70))
        }
    }

    @MainActor
    static func graphControl() {
        perform(.alignment)
    }

    /// Fires a single alignment haptic on the Force Touch trackpad.
    /// No-op on Macs without a trackpad — the API gracefully does nothing.
    @MainActor
    static func streamingTick() {
        softTick()
    }
}
