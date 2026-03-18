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
    var compact: Bool = false
    @Binding var retractNow: Bool
    var onRetractComplete: (() -> Void)? = nil

    @State private var displayText = "welcome back"
    @State private var cursorVisible = true
    @State private var hoverLocation: CGPoint? = nil

    private var theme: EpistemosTheme { ui.theme }
    private var greetingFont: Font { AppDisplayTypography.font(size: compact ? 22 : 44) }

    private var shouldAnimate: Bool {
        ui.activePanel == .home && !ui.windowOccluded
    }

    private var taskKey: String {
        "\(shouldAnimate)_\(retractNow)"
    }

    var body: some View {
        GeometryReader { proxy in
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let dx = (hoverLocation?.x ?? center.x) - center.x
            let dy = (hoverLocation?.y ?? center.y) - center.y
            let dist = sqrt(dx*dx + dy*dy)
            
            // Use granular Pull Radius knob (maps 0.0-1.0 to 80-240)
            let pullRadius: CGFloat = compact ? 80 : (80 + ui.landingGreetingPullRadius * 160)
            
            let pullIntensity = hoverLocation != nil ? max(0, 1.0 - (dist / pullRadius)) : 0
            // Re-increased pull factors for more organic motion
            let pullX = dx * pullIntensity * 0.18
            let pullY = dy * pullIntensity * 0.22
            
            // THE PERFORMANCE FIX: Gate entire drawing to 60fps to prevent app-wide stutter
            TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                Canvas { context, size in
                    if let resolved = context.resolveSymbol(id: "LumaFluid") {
                        // Use granular threshold knob (maps 0.0-1.0 to 0.1-0.9)
                        let threshold = 0.9 - (ui.landingGreetingThreshold * 0.8)
                        context.addFilter(.alphaThreshold(min: threshold, color: theme.fontAccent))
                        
                        // FIX: Only apply blur if we are hovering to prevent "already watery" look
                        if hoverLocation != nil {
                            // Use granular blur knob (maps 0.0-1.0 to 2-20)
                            let maxBlur = 2.0 + (ui.landingGreetingBlur * 18.0)
                            context.addFilter(.blur(radius: min(maxBlur, pow(pullIntensity, 1.1) * maxBlur * 0.9))) 
                        }
                        
                        context.draw(resolved, at: CGPoint(x: size.width / 2, y: size.height / 2))
                    }
                } symbols: {
                HStack(alignment: .center, spacing: 0) {
                    // Split the text into characters so we can apply local distortion
                    let chars = Array(displayText)
                    ForEach(0..<chars.count, id: \.self) { i in
                        let char = String(chars[i])
                        // Calculate local distance for this character (approximate based on width)
                        // A rough map from index to X position relative to center
                        let charXOffset = CGFloat(i) * 14.0 - CGFloat(chars.count) * 7.0 
                        let localDx = (hoverLocation?.x ?? center.x) - (center.x + charXOffset)
                        let localDist = sqrt(localDx*localDx + dy*dy)
                        
                        // Local intensity uses a slightly larger radius for "stickiness"
                        let stickRadius = pullRadius * 1.3
                        let localIntensity = hoverLocation != nil ? max(0, 1.0 - (localDist / stickRadius)) : 0
                        
                        let normalizedIndex = CGFloat(i) / CGFloat(max(chars.count - 1, 1)) - 0.5
                        let centerWeight = abs(normalizedIndex) * 2.0 // 0.0 at center, 1.0 at ends
                        
                        // Use granular center softening knob
                        let weightedIntensity = localIntensity * (ui.landingGreetingCenterSoftening + (1.0 - ui.landingGreetingCenterSoftening) * centerWeight)
                        let easedIntensity = pow(weightedIntensity, 1.5)
                        
                        // BALL OF WATER EXPANSION: Shift characters horizontally away from cursor to create a "bulge"
                        let expansionFactor = ui.landingGreetingExpansion * 25.0
                        let expansionX = (localDx < 0 ? 1 : -1) * easedIntensity * expansionFactor
                        
                        Text(char)
                            .font(greetingFont)
                            .foregroundColor(.black)
                            // Use granular pull knob
                            .offset(x: localDx * easedIntensity * ui.landingGreetingPull * 1.2 + expansionX, 
                                    y: dy * easedIntensity * ui.landingGreetingPull * 1.5)
                            // Use granular scale knob
                            .scaleEffect(1.0 + Double(easedIntensity) * ui.landingGreetingScale * 0.6)
                    }
                    
                    Rectangle()
                        .fill(.black)
                        .frame(width: compact ? 8 : 12, height: compact ? 20 : 36)
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                        .opacity(cursorVisible ? 1 : 0)
                        .animation(.easeInOut(duration: 0.3), value: cursorVisible)
                        .padding(.leading, dx * pullIntensity > 0 ? pullIntensity * 8 : 2) // Cursor stretches away more
                }
                    .offset(y: pullY * 0.3) 
                    .tag("LumaFluid")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .shadow(color: compact ? .clear : theme.fontAccent.opacity(0.12), radius: compact ? 0 : 8)
            // Viscous honey-like spring: Maps damping 0.0-1.0 to 0.2-0.9
            .animation(.interactiveSpring(response: 0.7, dampingFraction: 0.2 + ui.landingGreetingDamping * 0.7, blendDuration: 0.35), value: hoverLocation)
            .animation(.interactiveSpring(response: 0.7, dampingFraction: 0.2 + ui.landingGreetingDamping * 0.7, blendDuration: 0.35), value: pullIntensity)
        }
        // INCREASED FRAME: Give the liquid room to breathe to prevent cut-offs
        .frame(height: compact ? 40 : 180)
        .padding(.horizontal, compact ? 20 : 100)
        .contentShape(Rectangle())
        .onContinuousHover { phase in
            switch phase {
            case .active(let loc):
                hoverLocation = loc
            case .ended:
                hoverLocation = nil
            }
        }
        // Single reactive task — SwiftUI cancels + restarts when taskKey changes.
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
            // Small yield so SwiftUI's initial layout pass finishes before we start
            try? await Task.sleep(for: .milliseconds(50))
            guard !Task.isCancelled else { return }

            let blinkTask = Task { @MainActor in
                await cursorBlinkLoop()
            }
            await typewriterLoop()
            blinkTask.cancel()
        }
    }

    @MainActor
    private func cursorBlinkLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            cursorVisible.toggle()
        }
    }

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

    @MainActor
    private func typewriterLoop() async {
        var currentPhrase = "welcome back"
        while !Task.isCancelled {
            await typePhrase(currentPhrase)
            guard !Task.isCancelled else { return }

            try? await Task.sleep(for: .milliseconds(currentPhrase.count < 8 ? 1200 : Int.random(in: 2400...3200)))
            guard !Task.isCancelled else { return }

            await untypePhrase(currentPhrase)
            guard !Task.isCancelled else { return }

            try? await Task.sleep(for: .milliseconds(Int.random(in: 300...500)))
            currentPhrase = ["Greetings, Researcher", "Sup, Brainiac!", "click me to search\u{2026}"].randomElement() ?? "welcome back"
        }
    }

    @MainActor
    private func typePhrase(_ phrase: String) async {
        for i in 1...phrase.count {
            guard !Task.isCancelled else { return }
            displayText = String(phrase.prefix(i))
            try? await Task.sleep(for: .milliseconds(Int.random(in: 45...75)))
        }
    }

    @MainActor
    private func untypePhrase(_ phrase: String) async {
        var charIdx = phrase.count
        while charIdx > 0 && !Task.isCancelled {
            charIdx -= 1
            displayText = String(phrase.prefix(charIdx))
            try? await Task.sleep(for: .milliseconds(Int.random(in: 20...40)))
        }
    }
}
