import SwiftUI

/// Per-row flash highlight that wraps a transcript entry. New rows
/// flash an accent-tinted backdrop for ~600ms then fade to clear.
/// Keeps the static List rendering simple while making the terminal
/// feel alive ("the system just emitted that line").
///
/// Reduce-motion: skips the flash entirely; row renders flat.
struct HermesTranscriptRowFlash<Content: View>: View {
    let entry: HermesExpertTranscriptEntry
    let accent: Color
    @ViewBuilder let content: () -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var flashOpacity: CGFloat = 0.0

    var body: some View {
        content()
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(accent.opacity(reduceMotion ? 0 : flashOpacity))
            )
            .onAppear {
                guard !reduceMotion else { return }
                // Only flash if this row is fresh (within 1.2s of insertion).
                // Older rows scrolling into view don't flash.
                let age = Date().timeIntervalSince(entry.timestamp)
                guard age < 1.2 else { return }
                flashOpacity = flashStrength(for: entry.kind)
                withAnimation(.easeOut(duration: 0.6)) {
                    flashOpacity = 0.0
                }
            }
    }

    private func flashStrength(for kind: HermesExpertTranscriptEntry.Kind) -> CGFloat {
        switch kind {
        case .userInput:      return 0.0      // user input doesn't need flash
        case .systemEcho:     return 0.10
        case .systemResponse: return 0.18
        case .info:           return 0.08
        case .error:          return 0.22
        case .artifact:       return 0.14     // softer than response — the card itself draws attention
        }
    }
}
