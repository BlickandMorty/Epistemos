import SwiftUI

/// A component that combines character-by-character typewriter reveal with the interactive ASCIIRippleText effect.
struct TypewriterASCIIRippleText: View {
    let text: String
    var font: Font
    var color: Color
    var shadowColor: Color = .clear
    var shadowRadius: CGFloat = 0
    var configuration = ASCIIRippleConfiguration()
    var typingSpeed: Double = 0.025
    var initialDelay: Double = 0.05
    var rippleIntensity: Int = 1
    
    @State private var displayText = ""
    @State private var rippleTrigger = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ASCIIRippleText(
            text: displayText,
            font: font,
            color: color,
            shadowColor: shadowColor,
            shadowRadius: shadowRadius,
            configuration: configuration,
            manualTrigger: rippleTrigger,
            interactive: true,
            pulseOnAppear: false, // We'll trigger it manually after typing
            fixedHorizontal: false
        )
        .task(id: text) {
            await typeText()
        }
    }

    @MainActor
    private func typeText() async {
        guard !reduceMotion else {
            displayText = text
            return
        }

        // Reset and delay
        displayText = ""
        let safeInitialDelay = initialDelay.isFinite ? max(0, initialDelay) : 0
        let safeTypingSpeed = typingSpeed.isFinite ? max(0, typingSpeed) : 0
        try? await Task.sleep(for: .milliseconds(Int(safeInitialDelay * 1000)))

        for character in text {
            guard !Task.isCancelled else { return }
            displayText.append(character)
            
            // Occasionally trigger a small ripple while typing
            if Double.random(in: 0...1) < 0.1 {
                rippleTrigger += 1
            }
            
            try? await Task.sleep(for: .milliseconds(Int(safeTypingSpeed * 1000)))
        }

        // Final ripple when done
        if !text.isEmpty {
            rippleTrigger += 1
        }
    }
}
