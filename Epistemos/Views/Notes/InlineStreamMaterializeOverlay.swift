import AppKit
import SwiftUI

// SS-IL (owner 2026-06-20, Metal streaming overlay): a PURE DECORATION shimmer over the inline
// note-AI answer WHILE IT STREAMS — the answer "materializes" under a soft Metal scan band, then
// dissolves to plain editable text when streaming ends. Reuses the ThinkingGlow breathe/glow math
// via the `inline_stream_materialize` stitchable `.colorEffect` (compiled into default.metallib
// alongside thinking_glow_*).
//
// SAFETY (same envelope as InlineAnswerDecorationOverlay — see SSILInlineOverlaySafetyTests):
// imports NEITHER NSTextStorage NOR ProseTextView2 → CANNOT touch text storage. It only READS
// NoteChatState's published flags + the additive read-only `inlineResponseRectProvider`, paints
// light, and is `allowsHitTesting(false)` so typing/selection passes to TextKit2 underneath. The
// shimmer is gated to `isStreaming` and removed (with a dissolve) the instant streaming ends, so
// the materialized text is immediately, normally editable. Reduce-motion → the overlay is absent.
struct InlineStreamMaterializeOverlay: View {
    let theme: EpistemosTheme
    @Environment(NoteChatState.self) private var noteChat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var shouldShimmer: Bool {
        // Only the INLINE streaming answer (not the separate panel). Reduce-motion → off.
        noteChat.isStreaming && noteChat.hasResponse && !noteChat.useResponsePanel && !reduceMotion
    }

    var body: some View {
        ZStack {
            if shouldShimmer {
                GeometryReader { proxy in
                    let overlayGlobal = proxy.frame(in: .global)
                    if let screen = noteChat.inlineResponseRectProvider?(),
                       let local = InlineAnswerDecorationOverlay.localRect(
                            fromScreen: screen, overlayGlobal: overlayGlobal),
                       local.height > 1, local.width > 1 {
                        materializeBand(in: local)
                    }
                }
                .transition(.opacity)  // dissolve on removal when streaming ends
            }
        }
        // Materialize-in / dissolve-out as streaming toggles (static if reduce-motion).
        .animation(reduceMotion ? nil : .easeOut(duration: 0.4), value: noteChat.isStreaming)
        .allowsHitTesting(false)  // purely visual — typing/selection reach TextKit underneath
        .accessibilityHidden(true)
    }

    // MARK: - Metal materialize band

    private func materializeBand(in rect: CGRect) -> some View {
        let accent = theme.resolved.accent.color
        // Drive `time` from SwiftUI's animation clock (bounded so float precision stays clean).
        return TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3600)
            Rectangle()
                .fill(accent.opacity(0.0001))  // near-transparent canvas for the colorEffect
                .colorEffect(
                    ShaderLibrary.inline_stream_materialize(
                        .float2(Float(rect.width), Float(rect.height)),
                        .float(Float(t)),
                        .float(0.9),          // intensity
                        .color(accent)
                    )
                )
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
                .blendMode(.plusLighter)      // additive light over the streamed text
        }
    }
}
