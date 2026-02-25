import SwiftUI
import AppKit

// MARK: - Typewriter Plain Text
// Same progressive reveal but for plain Text views (Daily Brief).
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

// MARK: - Streaming Haptic Helper
// Fire-and-forget haptic pulse — used by ChatState's streaming token flush
// to give subtle feedback as tokens arrive.

enum HapticHelper {
    /// Fires a single alignment haptic on the Force Touch trackpad.
    /// No-op on Macs without a trackpad — the API gracefully does nothing.
    @MainActor
    static func streamingTick() {
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }
}
