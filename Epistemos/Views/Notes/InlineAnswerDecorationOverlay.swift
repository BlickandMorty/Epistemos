import AppKit
import SwiftUI

// SS-IL (owner 2026-06-20, safe-additive): a PURE DECORATION overlay over the note editor for
// the inline "Ask this note" AI answer. It draws the AI/user "cold box" SEPARATION (so the user
// is never confused about what's theirs vs the AI's) + a "scroll down for the answer" arrow when
// the answer is below the fold.
//
// SAFETY (the whole point — see SSILInlineOverlaySafetyTests): this file imports NEITHER
// NSTextStorage NOR ProseTextView2 — it CANNOT touch text storage. It only READS NoteChatState's
// published flags + the additive read-only `inlineResponseRectProvider`. The streaming pipeline
// (divider append, the 6 callbacks, undo grouping) is provably unchanged. `allowsHitTesting(false)`
// so all typing/selection passes straight through to the native TextKit2 text underneath.
struct InlineAnswerDecorationOverlay: View {
    let theme: EpistemosTheme
    @Environment(NoteChatState.self) private var noteChat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // Only decorate the INLINE response (not the separate panel mode). Reads, never sets.
        if noteChat.hasResponse, !noteChat.useResponsePanel {
            GeometryReader { proxy in
                let overlayGlobal = proxy.frame(in: .global)
                if let screenRect = noteChat.inlineResponseRectProvider?(),
                   let local = Self.localRect(fromScreen: screenRect, overlayGlobal: overlayGlobal) {
                    let belowFold = local.minY > proxy.size.height

                    // The AI "cold box": a faint AI-tinted wash + border over the inline
                    // answer so it reads as a distinct, clearly-AI block. Faint fill keeps the
                    // native text fully readable underneath.
                    coldBox(at: local)

                    // "Scroll down for the answer" — only when the answer is off-screen below.
                    if belowFold {
                        scrollAffordance
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                            .padding(.bottom, 16)
                    }
                }
            }
            .allowsHitTesting(false)  // purely visual — typing/selection reach TextKit underneath
            .accessibilityHidden(true)
        }
    }

    // MARK: - Cold box

    private func coldBox(at rect: CGRect) -> some View {
        let accent = theme.resolved.accent.color
        let inset = rect.insetBy(dx: -6, dy: -4)
        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(accent.opacity(theme.isDark ? 0.07 : 0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(accent.opacity(0.28), lineWidth: 1)
                )
                .frame(width: max(0, inset.width), height: max(0, inset.height))
                .position(x: inset.midX, y: inset.midY)

            // "AI" badge pinned to the box's top-left so authorship is unambiguous.
            Text("✦ AI")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(accent.opacity(0.9), in: Capsule())
                .position(x: inset.minX + 16, y: inset.minY - 1)
        }
    }

    // MARK: - Scroll affordance

    private var scrollAffordance: some View {
        let accent = theme.resolved.accent.color
        return VStack(spacing: 2) {
            Image(systemName: "chevron.down")
                .font(.system(size: 18, weight: .heavy))
                .modifier(BobModifier(active: !reduceMotion))
            Text("SCROLL DOWN FOR AI ANSWER")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(1)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(accent.opacity(0.92), in: Capsule())
        .shadow(color: .black.opacity(0.25), radius: 8, y: 3)
        .transition(.opacity)
    }

    // MARK: - Coordinate conversion (screen NSRect → this overlay's local space)

    /// Convert a screen-space rect (from `firstRect`) to this overlay's local coordinates.
    /// Read-only; touches no editor state. Handles flipped/unflipped content views.
    /// Internal (not private) so the SS-IL Metal materialize overlay reuses the exact
    /// same conversion — single source of truth for the screen→local math.
    static func localRect(fromScreen screenRect: CGRect, overlayGlobal: CGRect) -> CGRect? {
        guard let window = NSApp.keyWindow ?? NSApp.mainWindow,
              let content = window.contentView else { return nil }
        let windowRect = window.convertFromScreen(screenRect)          // → window (AppKit)
        let inContent = content.convert(windowRect, from: nil)         // → content view
        // content view (AppKit) → SwiftUI top-left global, then subtract the overlay origin.
        let globalY = content.isFlipped ? inContent.minY : content.bounds.height - inContent.maxY
        return CGRect(
            x: inContent.minX - overlayGlobal.minX,
            y: globalY - overlayGlobal.minY,
            width: inContent.width,
            height: inContent.height
        )
    }
}

// A gentle vertical bob for the scroll arrow (reduce-motion → static).
private struct BobModifier: ViewModifier {
    let active: Bool
    @State private var up = false
    func body(content: Content) -> some View {
        content
            .offset(y: active && up ? -4 : 0)
            .onAppear {
                guard active else { return }
                withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                    up = true
                }
            }
    }
}
