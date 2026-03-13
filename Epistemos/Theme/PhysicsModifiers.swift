import SwiftUI

// MARK: - Physics ViewModifiers
// Five opt-in modifiers that make views feel physically present.
// Each is self-contained, respects accessibilityReduceMotion, and follows
// the pattern established in GlassModifiers.swift.
//
// Performance contract:
// - Zero cost when idle (no timers, no per-frame work)
// - .breathe() uses TimelineView at 30Hz, gated by windowOccluded
// - All continuous effects pause when accessibilityReduceMotion is on
//
// WARNING: NO .repeatForever (Pitfall #10 — 70% idle CPU in v2).

// MARK: - 1. Physics Hover

/// Adds physical presence on hover: scale, shadow depth shift, optional 3D tilt.
/// Three tiers: .subtle (sidebar rows), .medium (cards), .lift (feature cards).
struct PhysicsHoverModifier: ViewModifier {
    let depth: Depth
    let enableTilt: Bool

    @State private var isHovered = false
    @State private var hoverLocation: CGPoint = CGPoint(x: 0.5, y: 0.5)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum Depth {
        case subtle  // sidebar rows — visible but not distracting
        case medium  // cards — clear lift with shadow
        case lift    // feature cards — dramatic 3D presence

        var scale: CGFloat {
            switch self {
            case .subtle: 1.015
            case .medium: 1.025
            case .lift:   1.035
            }
        }

        var shadowOpacity: Double {
            switch self {
            case .subtle: 0.12
            case .medium: 0.18
            case .lift:   0.24
            }
        }

        var shadowRadius: CGFloat {
            switch self {
            case .subtle: 6
            case .medium: 12
            case .lift:   20
            }
        }

        /// Background tint opacity on hover (gives clear visual feedback)
        var backgroundOpacity: Double {
            switch self {
            case .subtle: 0.04
            case .medium: 0.06
            case .lift:   0.08
            }
        }
    }

    /// Tilt angles derived from cursor position (±3°). Only active with enableTilt.
    private var tiltX: Double {
        guard isHovered, enableTilt else { return 0 }
        return (hoverLocation.y - 0.5) * -6
    }

    private var tiltY: Double {
        guard isHovered, enableTilt else { return 0 }
        return (hoverLocation.x - 0.5) * 6
    }

    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovered ? depth.scale : 1.0)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.primary.opacity(isHovered ? depth.backgroundOpacity : 0))
            )
            .shadow(
                color: .black.opacity(isHovered ? depth.shadowOpacity : 0),
                radius: isHovered ? depth.shadowRadius : 0,
                y: isHovered ? 3 : 0
            )
            .rotation3DEffect(.degrees(tiltX), axis: (x: 1, y: 0, z: 0))
            .rotation3DEffect(.degrees(tiltY), axis: (x: 0, y: 1, z: 0))
            .onContinuousHover { phase in
                guard !reduceMotion else {
                    switch phase {
                    case .active: isHovered = true
                    case .ended:  isHovered = false
                    }
                    return
                }
                switch phase {
                case .active(let location):
                    withAnimation(Motion.micro) { isHovered = true }
                    if enableTilt {
                        // Normalize to 0…1 within card bounds (assume ~200x140)
                        hoverLocation = CGPoint(
                            x: min(max(location.x / 200, 0), 1),
                            y: min(max(location.y / 140, 0), 1)
                        )
                    }
                case .ended:
                    withAnimation(Motion.smooth) {
                        isHovered = false
                        hoverLocation = CGPoint(x: 0.5, y: 0.5)
                    }
                }
            }
    }
}

// MARK: - 2. Physics Press

/// Depth on press, spring-back on release.
/// Scale 0.97 down with Motion.micro, snap back with Motion.sharp.
struct PhysicsPressModifier: ViewModifier {
    @State private var isPressed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .brightness(isPressed ? -0.02 : 0)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !isPressed else { return }
                        if reduceMotion {
                            isPressed = true
                        } else {
                            withAnimation(Motion.micro) { isPressed = true }
                        }
                    }
                    .onEnded { _ in
                        if reduceMotion {
                            isPressed = false
                        } else {
                            withAnimation(Motion.sharp) { isPressed = false }
                        }
                    }
            )
    }
}

// MARK: - 3. Breathe

/// Subtle idle oscillation — subliminal scale/opacity modulation.
/// Uses TimelineView at 30Hz, gated by windowOccluded + reduceMotion.
/// Default amplitude 0.3% — a 300px element moves ~1px.
struct BreatheModifier: ViewModifier {
    let amplitude: CGFloat
    let period: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(UIState.self) private var ui

    private var shouldAnimate: Bool { !reduceMotion && !ui.windowOccluded }

    func body(content: Content) -> some View {
        if shouldAnimate {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                let phase = sin(t * (2 * .pi / period))
                content
                    .scaleEffect(1.0 + amplitude * phase)
                    .opacity(1.0 - 0.04 * abs(phase))
            }
        } else {
            content
        }
    }
}

// MARK: - 4. Spring Entrance

/// Staggered appear animation: opacity, offset, and scale spring in.
/// Staggered spring entrance with overshoot bounce.
struct SpringEntranceModifier: ViewModifier {
    let index: Int
    let staggerDelay: Double

    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
            .scaleEffect(appeared ? 1 : 0.88)
            .animation(
                reduceMotion
                    ? .none
                    : Motion.settle.delay(Double(index) * staggerDelay),
                value: appeared
            )
            .onAppear {
                guard !appeared else { return }
                if reduceMotion {
                    appeared = true
                } else {
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(50))
                        appeared = true
                    }
                }
            }
    }
}

// MARK: - 5. Graph Reactive

/// Cross-view bridge: when the graph-hovered node matches this nodeId,
/// show a subtle accent bar + background fill on this view.
struct GraphReactiveModifier: ViewModifier {
    let nodeId: String

    @Environment(PhysicsCoordinator.self) private var physics

    private var isHighlighted: Bool {
        physics.graphHoveredNodeId == nodeId
    }

    func body(content: Content) -> some View {
        content
            .background {
                if isHighlighted {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.accentColor.opacity(0.12))
                        .transition(.opacity)
                }
            }
            .overlay(alignment: .leading) {
                if isHighlighted {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(Color.accentColor)
                        .frame(width: 3)
                        .transition(.scale(scale: 0, anchor: .leading).combined(with: .opacity))
                }
            }
            .animation(Motion.quick, value: isHighlighted)
    }
}

// MARK: - View Extensions

extension View {

    /// Add physical hover presence. Use `.subtle` for rows, `.medium` for cards, `.lift` for feature cards.
    func physicsHover(_ depth: PhysicsHoverModifier.Depth = .subtle, tilt: Bool = false) -> some View {
        modifier(PhysicsHoverModifier(depth: depth, enableTilt: tilt))
    }

    /// Scale down on press, spring back on release.
    func physicsPress() -> some View {
        modifier(PhysicsPressModifier())
    }

    /// Subtle idle breathing oscillation. Amplitude 0.003 = 0.3% scale (subliminal).
    func breathe(amplitude: CGFloat = 0.003, period: Double = 4.0) -> some View {
        modifier(BreatheModifier(amplitude: amplitude, period: period))
    }

    /// Staggered spring entrance. Pass index for cascade delay.
    func springEntrance(index: Int = 0, stagger: Double = 0.04) -> some View {
        modifier(SpringEntranceModifier(index: index, staggerDelay: stagger))
    }

    /// React when the graph hovers over the matching node.
    func graphReactive(nodeId: String) -> some View {
        modifier(GraphReactiveModifier(nodeId: nodeId))
    }
}

struct ASCIIRippleWave: Equatable {
    let startIndex: Int
    let startTime: TimeInterval
}

struct ASCIIRippleConfiguration: Equatable {
    var duration: TimeInterval = 0.8
    var characters: [Character] = Array(#".,·-─~+:;=*π""┐┌┘┴┬╗╔╝╚╬╠╣╩╦║░▒▓█▄▀▌▐■!?&#$@0123456789*"#)
    var preserveSpaces = true
    var spread: CGFloat = 1.0
    var waveThreshold: CGFloat = 3
    var characterMultiplier = 3
    var animationStep: TimeInterval = 0.04
    var waveBuffer: CGFloat = 5
}

enum ASCIIRippleEngine {
    static func characterIndex(forX x: CGFloat, width: CGFloat, textLength: Int) -> Int {
        guard textLength > 0 else { return 0 }
        guard width > 0 else { return textLength / 2 }
        let position = Int(round((x / width) * CGFloat(textLength)))
        return max(0, min(position, textLength - 1))
    }

    static func displayText(
        original: String,
        now: TimeInterval,
        waves: [ASCIIRippleWave],
        configuration: ASCIIRippleConfiguration
    ) -> String {
        let originalChars = Array(original)
        guard !originalChars.isEmpty, !waves.isEmpty else { return original }

        var output = originalChars
        for index in output.indices {
            let originalChar = originalChars[index]
            if configuration.preserveSpaces && originalChar == " " {
                continue
            }

            let effect = waveEffect(
                charIndex: index,
                originalChars: originalChars,
                now: now,
                waves: waves,
                configuration: configuration
            )
            if effect.shouldAnimate {
                output[index] = effect.character
            }
        }

        return String(output)
    }

    static func activeWaves(
        _ waves: [ASCIIRippleWave],
        now: TimeInterval,
        configuration: ASCIIRippleConfiguration
    ) -> [ASCIIRippleWave] {
        waves.filter { now - $0.startTime < configuration.duration }
    }

    private static func waveEffect(
        charIndex: Int,
        originalChars: [Character],
        now: TimeInterval,
        waves: [ASCIIRippleWave],
        configuration: ASCIIRippleConfiguration
    ) -> (shouldAnimate: Bool, character: Character) {
        var shouldAnimate = false
        var resultChar = originalChars[charIndex]

        for wave in waves {
            let age = now - wave.startTime
            guard age >= 0, age < configuration.duration else { continue }

            let progress = min(age / configuration.duration, 1)
            let distance = CGFloat(abs(charIndex - wave.startIndex))
            let maxDistance = CGFloat(max(wave.startIndex, originalChars.count - wave.startIndex - 1))
            let radius = (progress * (maxDistance + configuration.waveBuffer)) / configuration.spread

            guard distance <= radius else { continue }
            shouldAnimate = true

            let intensity = max(0, radius - distance)
            if intensity <= configuration.waveThreshold, intensity > 0 {
                let scrambleIndex = (Int(distance) * configuration.characterMultiplier
                    + Int(age / configuration.animationStep)) % configuration.characters.count
                resultChar = configuration.characters[scrambleIndex]
            }
        }

        return (shouldAnimate, resultChar)
    }
}

struct ASCIIRippleText: View {
    let text: String
    var font: Font
    var color: Color
    var shadowColor: Color = .clear
    var shadowRadius: CGFloat = 0
    var configuration = ASCIIRippleConfiguration()
    var manualTrigger = 0
    var interactive = true

    @State private var measuredWidth: CGFloat = 1
    @State private var waves: [ASCIIRippleWave] = []
    @State private var lastHoveredIndex: Int?
    @State private var cleanupTask: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        styledText(text)
            .hidden()
            .overlay(alignment: .leading) {
                animatedText
            }
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { measuredWidth = max(proxy.size.width, 1) }
                        .onChange(of: proxy.size.width) { _, newValue in
                            measuredWidth = max(newValue, 1)
                        }
                }
            }
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                guard interactive, !reduceMotion else { return }
                switch phase {
                case .active(let location):
                    let index = ASCIIRippleEngine.characterIndex(
                        forX: location.x,
                        width: measuredWidth,
                        textLength: text.count
                    )
                    guard index != lastHoveredIndex else { return }
                    lastHoveredIndex = index
                    startWave(at: index)
                case .ended:
                    lastHoveredIndex = nil
                }
            }
            .onChange(of: manualTrigger) { _, _ in
                guard manualTrigger > 0, !reduceMotion, !text.isEmpty else { return }
                startWave(at: text.count / 2)
            }
            .onChange(of: text) { _, _ in
                lastHoveredIndex = nil
            }
            .onDisappear {
                cleanupTask?.cancel()
            }
    }

    @ViewBuilder
    private var animatedText: some View {
        if reduceMotion || waves.isEmpty || text.isEmpty {
            styledText(text)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                let now = context.date.timeIntervalSinceReferenceDate
                let active = ASCIIRippleEngine.activeWaves(
                    waves,
                    now: now,
                    configuration: configuration
                )
                styledText(
                    ASCIIRippleEngine.displayText(
                        original: text,
                        now: now,
                        waves: active,
                        configuration: configuration
                    )
                )
            }
        }
    }

    private func styledText(_ value: String) -> some View {
        Text(value)
            .font(font)
            .foregroundStyle(color)
            .shadow(color: shadowColor, radius: shadowRadius)
            .fixedSize(horizontal: true, vertical: true)
    }

    private func startWave(at index: Int) {
        let clampedIndex = max(0, min(index, max(text.count - 1, 0)))
        waves.append(
            ASCIIRippleWave(
                startIndex: clampedIndex,
                startTime: Date.timeIntervalSinceReferenceDate
            )
        )
        if waves.count > 8 {
            waves.removeFirst(waves.count - 8)
        }
        scheduleCleanup()
    }

    private func scheduleCleanup() {
        cleanupTask?.cancel()
        cleanupTask = Task { @MainActor in
            while !Task.isCancelled {
                let active = ASCIIRippleEngine.activeWaves(
                    waves,
                    now: Date.timeIntervalSinceReferenceDate,
                    configuration: configuration
                )
                if active.count == waves.count, !active.isEmpty {
                    try? await Task.sleep(for: .milliseconds(50))
                    continue
                }
                waves = active
                guard !waves.isEmpty else { break }
                try? await Task.sleep(for: .milliseconds(50))
            }
        }
    }
}

struct ASCIIFrameAnimationConfiguration: Equatable {
    var frames: [String]
    var frameDuration: TimeInterval

    static let previewScanner = ASCIIFrameAnimationConfiguration(
        frames: [
            "[>    ]",
            "[>>   ]",
            "[>>>  ]",
            "[ >>> ]",
            "[  >>>]",
            "[   >>]",
            "[    >]",
            "[     ]",
        ],
        frameDuration: 0.08
    )
}

enum ASCIIFrameAnimationEngine {
    static func frame(
        now: TimeInterval,
        startTime: TimeInterval,
        configuration: ASCIIFrameAnimationConfiguration
    ) -> String {
        guard !configuration.frames.isEmpty else { return "" }
        guard configuration.frameDuration > 0 else { return configuration.frames[0] }
        let elapsed = max(0, now - startTime)
        let frameIndex = Int(elapsed / configuration.frameDuration) % configuration.frames.count
        return configuration.frames[frameIndex]
    }
}

struct ASCIIFrameAnimationText: View {
    var configuration: ASCIIFrameAnimationConfiguration
    var font: Font
    var color: Color

    @State private var startTime = Date.timeIntervalSinceReferenceDate
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(UIState.self) private var ui

    private var shouldAnimate: Bool {
        !reduceMotion && !ui.windowOccluded && configuration.frames.count > 1
    }

    var body: some View {
        if shouldAnimate {
            TimelineView(.animation(minimumInterval: configuration.frameDuration)) { context in
                Text(
                    ASCIIFrameAnimationEngine.frame(
                        now: context.date.timeIntervalSinceReferenceDate,
                        startTime: startTime,
                        configuration: configuration
                    )
                )
                .font(font)
                .foregroundStyle(color)
                .monospacedDigit()
                .fixedSize(horizontal: true, vertical: true)
            }
            .onAppear {
                startTime = Date.timeIntervalSinceReferenceDate
            }
        } else {
            Text(configuration.frames.first ?? "")
                .font(font)
                .foregroundStyle(color)
                .monospacedDigit()
                .fixedSize(horizontal: true, vertical: true)
        }
    }
}
