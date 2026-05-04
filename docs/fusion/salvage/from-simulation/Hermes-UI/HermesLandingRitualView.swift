//
//  HermesLandingRitualView.swift
//  Simulation Mode S9 — orchestrator for the §8.2.2 7-phase
//  Hermes landing-page transformation ritual.
//
//  Composes:
//   - Phase 0  Anchor: cross-fade to deep indigo `#0A0A1F`
//   - Phase 1  Portrait emerges (left half, ASCII)
//   - Phase 2  ASCII wave sweeps across canvas
//   - Phase 3  Hero title types on (right half, pixel-art)
//   - Phase 4  Gold halo pulses (separate additive quad)
//   - Phase 5  Snake mascot coils in (lower center)
//   - Phase 6  Single-frame glare flash sweeps left-to-right
//   - Phase 7  Chat surface emerges from bottom edge
//
//  Reduce-motion variant per §8.2.4 collapses to ~450ms instant
//  pose. The ritual is theatre over honest substrate; the
//  underlying Hermes session begins the moment the user
//  invokes the action, NOT when the ritual finishes (§8.2).
//

import SwiftUI

@MainActor
public struct HermesLandingRitualView: View {
    /// Companion id of the Hermes faculty bound to this ritual.
    /// The session was already opened by the host when this
    /// view appeared — the ritual is purely visual ceremony.
    public let companionId: CompanionId

    /// Called when the ritual finishes phase 7 (chat surface
    /// emerged) so the host can hand control to the chat UI.
    public let onComplete: () -> Void

    @State private var currentPhase: HermesLandingPhase = .anchor
    @State private var portraitReveal: Int = 0
    @State private var heroTypeOnProgress: Double = 0.0
    @State private var haloOpacity: Double = 0.0
    @State private var snakeOffsetY: CGFloat = 60
    @State private var snakeOpacity: Double = 0.0
    @State private var glareProgress: Double = 0.0
    @State private var chatOffset: CGFloat = 250
    @State private var hasStarted: Bool = false

    public init(
        companionId: CompanionId,
        onComplete: @escaping () -> Void
    ) {
        self.companionId = companionId
        self.onComplete = onComplete
    }

    public var body: some View {
        ZStack {
            // Phase 0 anchor — deep indigo base layer per §8.2.2.
            Color(red: 0x0A / 255.0, green: 0x0A / 255.0, blue: 0x1F / 255.0)
                .ignoresSafeArea()

            // Halo sits BEHIND wordmark + portrait per §8.2.3
            // ("the gold halo is a separate additive quad …
            // never a Gaussian blur of the wordmark").
            HermesGoldHaloView(opacity: haloOpacity)
                .position(x: 480, y: 240)

            HStack(alignment: .center, spacing: 36) {
                AsciiPortraitView(
                    art: AsciiPortraitArt.epistemosFallback,
                    pointSize: 11,
                    foregroundColor: Color(red: 0.85, green: 0.95, blue: 1.0),
                    revealCharacters: portraitReveal
                )
                HermesHeroWordmarkView(typeOnProgress: heroTypeOnProgress)
            }
            .padding(.horizontal, 48)

            // Phase 5 snake mascot — placeholder geometry per
            // §8.2.1 Epistemos-fallback substitution. S5.7 / S10
            // swap in canonical SVG / atlas tile.
            snakeFallback
                .opacity(snakeOpacity)
                .offset(y: 180 + snakeOffsetY)

            // Phase 6 glare flash.
            HermesGlareFlashView(progress: glareProgress)
                .ignoresSafeArea()

            // Phase 7 chat surface emerges from bottom.
            chatPlaceholder
                .frame(maxWidth: .infinity, maxHeight: 250)
                .offset(y: chatOffset)
                .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .frame(minWidth: 720, minHeight: 480)
        .onAppear {
            guard !hasStarted else { return }
            hasStarted = true
            Task { await runRitual() }
        }
    }

    // MARK: - Snake placeholder

    @ViewBuilder
    private var snakeFallback: some View {
        // Epistemos-fallback per §8.2.1 substitution allowance.
        // Canonical NousResearch caduceus SVG arrives via S5.7.
        // Here we render a serpentine silhouette using a Path
        // so the visual contract (gold/orange hovering serpent)
        // holds without runtime image dependencies.
        Canvas { ctx, size in
            let coilRadius: CGFloat = 28
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            for i in 0..<5 {
                let angle = Double(i) * 72.0 * .pi / 180.0
                let x = center.x + cos(angle) * coilRadius
                let y = center.y + sin(angle) * (coilRadius * 0.5)
                let dot = Path(ellipseIn: CGRect(
                    x: x - 6, y: y - 6, width: 12, height: 12
                ))
                ctx.fill(
                    dot,
                    with: .color(Color(red: 1.0, green: 0.84, blue: 0.0))
                )
            }
            // Eye highlights so the silhouette reads as a head.
            let head = Path(ellipseIn: CGRect(
                x: center.x - 8, y: center.y - 14, width: 16, height: 16
            ))
            ctx.fill(head, with: .color(Color(red: 0.85, green: 0.69, blue: 0.22)))
        }
        .frame(width: 96, height: 96)
        .accessibilityLabel("Hermes serpent mascot (Epistemos fallback)")
    }

    // MARK: - Chat placeholder

    @ViewBuilder
    private var chatPlaceholder: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Hermes Faculty — Graph Session")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color(red: 0.85, green: 0.69, blue: 0.22))
            Text("Ask the graph faculty something.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
            HStack {
                TextField("Type a question…", text: .constant(""))
                    .textFieldStyle(.roundedBorder)
                    .disabled(true)
                Button("Send") {}
                    .disabled(true)
            }
        }
        .padding(12)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(
                    Rectangle()
                        .stroke(
                            Color(red: 0.85, green: 0.69, blue: 0.22).opacity(0.4),
                            lineWidth: 1
                        )
                )
        )
    }

    // MARK: - Ritual timeline driver

    private func runRitual() async {
        if HermesLandingTimeline.isReduceMotionEnabled {
            await runReduceMotionVariant()
        } else {
            await runStandardRitual()
        }
        onComplete()
    }

    /// Standard 7-phase opulent treatment (§8.2.2 — ~4.7 s total).
    private func runStandardRitual() async {
        // Phase 0 — anchor cross-fade is implicit (the parent
        // view fades in atop the prior surface).
        try? await Task.sleep(for: .milliseconds(HermesLandingPhase.anchor.standardDurationMs))

        // Phase 1 — portrait emerges. Reveal characters in a
        // single sweep so the typing cadence stays integer-step
        // per I-16 (no per-pixel sub-frame interpolation).
        currentPhase = .portraitEmerges
        let portraitTotalChars = AsciiPortraitArt.epistemosFallback.count
        let p1ms = HermesLandingPhase.portraitEmerges.standardDurationMs
        let p1Steps = 24
        for i in 1...p1Steps {
            withAnimation(.linear(duration: 0)) {
                portraitReveal = (portraitTotalChars * i) / p1Steps
            }
            try? await Task.sleep(for: .milliseconds(p1ms / p1Steps))
        }
        portraitReveal = portraitTotalChars

        // Phase 2 — ASCII wave (stub: hold portrait, animate via
        // the canvas; for S9 minimum viable we skip the visible
        // wave canvas and let phase 3 begin so the ritual stays
        // canonical-feeling without S5.7 banner asset).
        currentPhase = .asciiWave
        try? await Task.sleep(for: .milliseconds(HermesLandingPhase.asciiWave.standardDurationMs))

        // Phase 3 — hero title types on glyph-by-glyph. Use a
        // discrete-step animation so each glyph appears whole
        // (no sub-glyph interpolation per §8.2.2 + I-16).
        currentPhase = .heroTitleTypes
        let p3ms = HermesLandingPhase.heroTitleTypes.standardDurationMs
        let glyphCount = "HERMES-AGENT".count
        for i in 1...glyphCount {
            heroTypeOnProgress = Double(i) / Double(glyphCount)
            try? await Task.sleep(for: .milliseconds(p3ms / glyphCount))
        }
        heroTypeOnProgress = 1.0

        // Phase 4 — gold halo pulse: 0 → 0.6 → 0.3 then hold.
        currentPhase = .goldHaloPulse
        let p4ms = HermesLandingPhase.goldHaloPulse.standardDurationMs
        withAnimation(.easeOut(duration: Double(p4ms / 2) / 1000.0)) {
            haloOpacity = 0.6
        }
        try? await Task.sleep(for: .milliseconds(p4ms / 2))
        withAnimation(.easeIn(duration: Double(p4ms / 2) / 1000.0)) {
            haloOpacity = 0.3
        }
        try? await Task.sleep(for: .milliseconds(p4ms / 2))

        // Phase 5 — snake coils in (5 frames, integer pixel
        // motion per §8.2.2).
        currentPhase = .snakeCoils
        let p5ms = HermesLandingPhase.snakeCoils.standardDurationMs
        let coilFrames = 5
        for frame in 0..<coilFrames {
            withAnimation(.linear(duration: 0)) {
                snakeOpacity = Double(frame + 1) / Double(coilFrames)
                snakeOffsetY = 60 - CGFloat(frame * 15)
            }
            try? await Task.sleep(for: .milliseconds(p5ms / coilFrames))
        }
        snakeOpacity = 1.0
        snakeOffsetY = 0

        // Phase 6 — glare flash (single frame additive).
        currentPhase = .glareFlash
        let p6ms = HermesLandingPhase.glareFlash.standardDurationMs
        let glareSteps = 12
        for i in 0...glareSteps {
            glareProgress = Double(i) / Double(glareSteps)
            try? await Task.sleep(for: .milliseconds(p6ms / glareSteps))
        }
        glareProgress = 0.0

        // Phase 7 — chat surface slides up.
        currentPhase = .chatEmerges
        let p7ms = HermesLandingPhase.chatEmerges.standardDurationMs
        withAnimation(.easeOut(duration: Double(p7ms) / 1000.0)) {
            chatOffset = 0
        }
        try? await Task.sleep(for: .milliseconds(p7ms))
    }

    /// Reduce-motion variant per §8.2.4 — ~450ms total. Cross-
    /// fade in, all elements appear at final pose, halo holds at
    /// 0.3, chat fades in.
    private func runReduceMotionVariant() async {
        try? await Task.sleep(for: .milliseconds(HermesLandingPhase.anchor.reduceMotionDurationMs))
        portraitReveal = AsciiPortraitArt.epistemosFallback.count
        heroTypeOnProgress = 1.0
        haloOpacity = 0.3
        snakeOpacity = 1.0
        snakeOffsetY = 0
        try? await Task.sleep(for: .milliseconds(HermesLandingPhase.chatEmerges.reduceMotionDurationMs))
        withAnimation(.easeOut(duration: 0.3)) {
            chatOffset = 0
        }
    }
}
