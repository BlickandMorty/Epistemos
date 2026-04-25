// GraphFirstOpenTitle.swift
//
// Large "knowledge graph" title shown ONCE when the graph overlay is
// opened for the first time in a session. Uses the RetroGaming font,
// typewriter character reveal, a soft drop shadow, and a blur-in /
// blur-out wrapper so it fades in crisp and dissolves out blurry.
// User 2026-04-04.

import SwiftUI

struct GraphFirstOpenTitle: View {
    /// Theme resolved externally so the title matches light/dark overlay.
    let isDark: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var displayText: String = ""
    @State private var blurRadius: CGFloat = 14
    @State private var opacity: Double = 0
    @State private var overallScale: CGFloat = 1.0
    @State private var hasFinished = false

    private let fullText = "knowledge graph"
    /// Same timing family as LiquidGreeting / LandingView's typewriter.
    private let perCharMs: ClosedRange<Int> = 55...90

    private var titleColor: Color {
        // High-contrast against the overlay's tint in both modes.
        isDark ? Color.white : Color(red: 0.08, green: 0.08, blue: 0.12)
    }

    private var shadowColor: Color {
        // Soft drop shadow — bigger in dark mode (pure glow) than light
        // mode (subtle offset). Matches the "shadow behind it" feedback.
        isDark
            ? Color.white.opacity(0.22)
            : Color(red: 0.30, green: 0.40, blue: 0.60).opacity(0.35)
    }

    var body: some View {
        Text(displayText)
            .font(.custom(AppDisplayTypography.displayFontName, size: 88))
            .foregroundStyle(titleColor)
            .tracking(4)
            // Two-layer shadow: soft glow + crisp offset for depth.
            .shadow(color: shadowColor, radius: 18, x: 0, y: 0)
            .shadow(color: shadowColor.opacity(0.55), radius: 6, x: 0, y: 3)
            .scaleEffect(overallScale)
            .blur(radius: blurRadius)
            .opacity(opacity)
            .frame(maxWidth: .infinity)
            .task { await runAnimation() }
    }

    @MainActor
    private func runAnimation() async {
        // Reduce Motion: skip blur-in, typewriter, and blur-out dissolve.
        // Show the title statically for the same hold duration so the
        // user has time to read it, then snap-fade out without scaling.
        if reduceMotion {
            displayText = fullText
            opacity = 1.0
            blurRadius = 0
            try? await Task.sleep(for: .milliseconds(900))
            opacity = 0
            return
        }

        // Initial fade/blur-in — the title materializes out of blur.
        withAnimation(.easeOut(duration: 0.55)) {
            opacity = 1.0
            blurRadius = 0.0
        }
        // Short beat before typing starts.
        try? await Task.sleep(for: .milliseconds(180))

        // Typewriter reveal — same timing as LiquidGreeting's typer.
        for i in 1...fullText.count {
            guard !Task.isCancelled else { return }
            displayText = String(fullText.prefix(i))
            let last = displayText.last ?? " "
            var delay = Int.random(in: perCharMs)
            if last == " " { delay += 40 }
            if Double.random(in: 0...1) < 0.08 { delay += Int.random(in: 100...220) }
            try? await Task.sleep(for: .milliseconds(delay))
        }
        hasFinished = true

        // Hold at full clarity for a beat so the user can read it.
        try? await Task.sleep(for: .milliseconds(900))

        // Blur-out dissolve — title gets blurry AND slightly larger as
        // it fades, so it feels like it's receding into the graph.
        withAnimation(.easeIn(duration: 0.8)) {
            blurRadius = 18
            opacity = 0
            overallScale = 1.05
        }
    }
}

/// Hosting wrapper so HologramOverlay can add the title as a plain NSView.
/// The wrapper auto-removes itself from its superview after the animation
/// completes — the title is a one-shot visual, not a persistent overlay.
@MainActor
final class GraphFirstOpenTitleHost {
    private weak var hostView: NSHostingView<AnyView>?

    func install(in parent: NSView, isDark: Bool) {
        // Remove any previous instance (defensive — this should only be
        // installed once per session).
        hostView?.removeFromSuperview()

        let view = NSHostingView(
            rootView: AnyView(GraphFirstOpenTitle(isDark: isDark))
        )
        view.translatesAutoresizingMaskIntoConstraints = false
        // Transparent background — Metal graph shows through.
        view.wantsLayer = true
        view.layer?.backgroundColor = .clear
        parent.addSubview(view)
        hostView = view

        NSLayoutConstraint.activate([
            view.centerXAnchor.constraint(equalTo: parent.centerXAnchor),
            // Roughly 22% down from the top — above the graph's visual
            // center so the title sits in the "sky" of the viewport.
            view.topAnchor.constraint(
                equalTo: parent.topAnchor,
                constant: 120
            ),
            view.heightAnchor.constraint(equalToConstant: 160),
            view.widthAnchor.constraint(lessThanOrEqualTo: parent.widthAnchor, constant: -80),
        ])

        // Auto-remove after the full animation completes (enter + hold +
        // exit ≈ 2.7s, plus typewriter time ~1.5s). 4.5s is safely past.
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(4.5))
            self?.hostView?.removeFromSuperview()
            self?.hostView = nil
        }
    }
}
