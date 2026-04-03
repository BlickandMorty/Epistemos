import Foundation
import SwiftUI

private enum AssistantComposerWarmup {
    static let activationDuration: Double = 0.28
    static let deactivationDuration: Double = 0.18

    static func animation(for phase: AssistantComposerStatusPhase) -> Animation {
        phase == .idle
            ? .easeOut(duration: deactivationDuration)
            : .easeInOut(duration: activationDuration)
    }
}

enum AssistantComposerStatusPhase: Equatable {
    case idle
    case analyzing
    case typing

    init(notePhase: NoteChatToolbarStatusPhase) {
        switch notePhase {
        case .idle:
            self = .idle
        case .analyzing:
            self = .analyzing
        case .typing:
            self = .typing
        }
    }

    static func resolve(isActive: Bool, streamingText: String) -> Self {
        guard isActive else { return .idle }
        let visibleText = UserFacingModelOutput.streamingVisibleText(from: streamingText)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return visibleText.isEmpty ? .analyzing : .typing
    }
}

struct AssistantComposerHaloStyle: Equatable {
    enum Tone: Equatable {
        case cool
        case warm
    }

    let tone: Tone
    let lineWidth: CGFloat
    let strokeOpacity: Double
    let primaryBlurRadius: CGFloat
    let primaryOpacity: Double
    let secondaryBlurRadius: CGFloat
    let secondaryOpacity: Double
    let expansion: CGFloat

    static func resolve(for phase: AssistantComposerStatusPhase) -> Self? {
        switch phase {
        case .idle:
            nil
        case .analyzing:
            Self(
                tone: .cool,
                lineWidth: 1.8,
                strokeOpacity: 0.16,
                primaryBlurRadius: 7,
                primaryOpacity: 0.32,
                secondaryBlurRadius: 15,
                secondaryOpacity: 0.20,
                expansion: 10
            )
        case .typing:
            Self(
                tone: .warm,
                lineWidth: 1.35,
                strokeOpacity: 0.12,
                primaryBlurRadius: 6,
                primaryOpacity: 0.24,
                secondaryBlurRadius: 12,
                secondaryOpacity: 0.14,
                expansion: 8
            )
        }
    }

    func palette(accent: Color) -> [Color] {
        switch tone {
        case .cool:
            return [
                Color(hue: 0.77, saturation: 0.54, brightness: 0.98),
                accent,
                Color(hue: 0.58, saturation: 0.48, brightness: 1.0),
                Color(hue: 0.51, saturation: 0.34, brightness: 1.0),
                Color(hue: 0.77, saturation: 0.54, brightness: 0.98),
            ]
        case .warm:
            return [
                Color(hue: 0.14, saturation: 0.56, brightness: 1.0),
                Color(hue: 0.06, saturation: 0.46, brightness: 0.98),
                Color(hue: 0.95, saturation: 0.38, brightness: 0.98),
                accent,
                Color(hue: 0.14, saturation: 0.56, brightness: 1.0),
            ]
        }
    }
}

struct AssistantToolbarAskBarChromeTuning: Equatable {
    let haloStrokeOpacityMultiplier: Double
    let haloLineWidthMultiplier: CGFloat
    let borderOpacityMultiplier: Double
    let borderLineWidth: CGFloat
    let surfaceShadowOpacity: Double
    let surfaceShadowRadius: CGFloat
    let surfaceShadowYOffset: CGFloat
    let outlineShadowOpacity: Double
    let outlineShadowRadius: CGFloat
    let outlineShadowYOffset: CGFloat

    static let standard = Self(
        haloStrokeOpacityMultiplier: 1.0,
        haloLineWidthMultiplier: 1.0,
        borderOpacityMultiplier: 1.0,
        borderLineWidth: 0.75,
        surfaceShadowOpacity: 0.0,
        surfaceShadowRadius: 0.0,
        surfaceShadowYOffset: 0.0,
        outlineShadowOpacity: 0.0,
        outlineShadowRadius: 0.0,
        outlineShadowYOffset: 0.0
    )

    static let noteAskBar = Self(
        haloStrokeOpacityMultiplier: 0.62,
        haloLineWidthMultiplier: 0.88,
        borderOpacityMultiplier: 0.58,
        borderLineWidth: 0.65,
        surfaceShadowOpacity: 0.12,
        surfaceShadowRadius: 4.0,
        surfaceShadowYOffset: 1.0,
        outlineShadowOpacity: 0.08,
        outlineShadowRadius: 2.0,
        outlineShadowYOffset: 0.5
    )
}

extension AssistantComposerHaloStyle {
    func adjusted(for chrome: AssistantToolbarAskBarChromeTuning) -> Self {
        Self(
            tone: tone,
            lineWidth: lineWidth * chrome.haloLineWidthMultiplier,
            strokeOpacity: strokeOpacity * chrome.haloStrokeOpacityMultiplier,
            primaryBlurRadius: primaryBlurRadius,
            primaryOpacity: primaryOpacity,
            secondaryBlurRadius: secondaryBlurRadius,
            secondaryOpacity: secondaryOpacity,
            expansion: expansion
        )
    }
}

struct AssistantComposerStatusLabelState: Equatable {
    let text: String
    let usesSweepHighlight: Bool

    static func resolve(
        inputText: String,
        phase: AssistantComposerStatusPhase,
        idleText: String,
        showsIdleLabel: Bool = true,
        analyzingText: String = "Thinking…",
        typingText: String = "Responding…"
    ) -> Self? {
        guard inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        switch phase {
        case .idle:
            return showsIdleLabel ? Self(text: idleText, usesSweepHighlight: false) : nil
        case .analyzing:
            return Self(text: analyzingText, usesSweepHighlight: true)
        case .typing:
            return Self(text: typingText, usesSweepHighlight: true)
        }
    }
}

struct AssistantAnimatedStatusLabel: View {
    let state: AssistantComposerStatusLabelState
    let accent: Color
    let phase: AssistantComposerStatusPhase
    let theme: EpistemosTheme
    let font: Font
    let haloStyle: AssistantComposerHaloStyle?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var activationProgress: CGFloat = 0

    private var baseTextColor: Color {
        switch phase {
        case .idle:
            theme.resolved.foreground.color.opacity(0.48)
        case .analyzing, .typing:
            theme.resolved.foreground.color.opacity(theme.isDark ? 0.62 : 0.52)
        }
    }

    private var palette: [Color] {
        if let haloStyle {
            return haloStyle.palette(accent: accent)
        }
        return [
            accent.opacity(0.80),
            theme.resolved.foreground.color.opacity(0.92),
            accent.opacity(0.68),
        ]
    }

    private var sweepWidth: CGFloat {
        min(max(CGFloat(state.text.count) * 14, 132), 240)
    }

    var body: some View {
        Group {
            if phase == .idle {
                labelText
                    .foregroundStyle(baseTextColor)
                    .allowsHitTesting(false)
            } else {
                warmingActiveLabel
            }
        }
        .onAppear {
            syncActivationProgress(for: phase, animated: false)
        }
        .onChange(of: phase) { _, newPhase in
            syncActivationProgress(for: newPhase, animated: true)
        }
    }

    private var warmingActiveLabel: some View {
        ZStack(alignment: .leading) {
            labelText
                .foregroundStyle(baseTextColor.opacity(0.74))
                .opacity(Double(max(0, 1 - activationProgress)))

            animatedActiveLabel
                .opacity(Double(activationProgress))
                .blur(radius: (1 - activationProgress) * 2.2)
                .scaleEffect(
                    x: 0.985 + (activationProgress * 0.015),
                    y: 1,
                    anchor: .leading
                )
        }
        .allowsHitTesting(false)
    }

    private var animatedActiveLabel: some View {
        Group {
            if reduceMotion {
                labelText
                    .foregroundStyle(
                        LinearGradient(colors: palette, startPoint: .leading, endPoint: .trailing)
                    )
                    .opacity(0.86)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { context in
                    let elapsed = context.date.timeIntervalSinceReferenceDate
                    let paletteX = shimmerOffset(width: sweepWidth, elapsed: elapsed, speed: 30)
                    let silverX = shimmerOffset(width: sweepWidth, elapsed: elapsed, speed: 48)

                    ZStack(alignment: .leading) {
                        labelText
                            .foregroundStyle(baseTextColor)

                        shimmerBand(
                            colors: paletteBandColors,
                            width: sweepWidth * 0.9,
                            offset: paletteX,
                            blurRadius: 0
                        )
                        .opacity(0.94)

                        if state.usesSweepHighlight {
                            shimmerBand(
                                colors: silverBandColors,
                                width: sweepWidth * 0.42,
                                offset: silverX,
                                blurRadius: 2.4
                            )
                            .opacity(0.74)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .shadow(color: palette.first?.opacity(0.14) ?? .clear, radius: 3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .allowsHitTesting(false)
    }

    private var labelText: some View {
        Text(state.text)
            .font(font)
            .lineLimit(1)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var alignedLabelMask: some View {
        labelText
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var paletteBandColors: [Color] {
        [.clear] + palette.map { $0.opacity(0.98) } + [.clear]
    }

    private var silverBandColors: [Color] {
        [
            .clear,
            Color.white.opacity(0.08),
            Color.white.opacity(0.96),
            Color.white.opacity(0.18),
            .clear,
        ]
    }

    private func shimmerOffset(width: CGFloat, elapsed: TimeInterval, speed: Double) -> CGFloat {
        let cycle = width * 1.9
        return CGFloat((elapsed * speed).truncatingRemainder(dividingBy: cycle)) - (width * 0.95)
    }

    private func shimmerBand(
        colors: [Color],
        width: CGFloat,
        offset: CGFloat,
        blurRadius: CGFloat
    ) -> some View {
        LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
            .frame(width: width)
            .offset(x: offset)
            .blur(radius: blurRadius)
            .mask(alignedLabelMask)
            .blendMode(.screen)
    }

    private func syncActivationProgress(
        for phase: AssistantComposerStatusPhase,
        animated: Bool
    ) {
        let nextValue: CGFloat = phase == .idle ? 0 : 1
        guard activationProgress != nextValue else { return }
        if animated {
            withAnimation(AssistantComposerWarmup.animation(for: phase)) {
                activationProgress = nextValue
            }
        } else {
            activationProgress = nextValue
        }
    }
}

struct AssistantTypingIndicatorDots: View {
    let theme: EpistemosTheme
    let accent: Color
    let dotSize: CGFloat
    let spacing: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        theme: EpistemosTheme,
        accent: Color,
        dotSize: CGFloat = 6,
        spacing: CGFloat = 5
    ) {
        self.theme = theme
        self.accent = accent
        self.dotSize = dotSize
        self.spacing = spacing
    }

    var body: some View {
        Group {
            if reduceMotion {
                dotRow(activeIndex: nil)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 12.0)) { context in
                    let elapsed = context.date.timeIntervalSinceReferenceDate
                    let activeIndex = Int((elapsed * 2.4).truncatingRemainder(dividingBy: 3))
                    dotRow(activeIndex: activeIndex)
                }
            }
        }
        .frame(height: dotSize + 4)
        .accessibilityLabel("Assistant is typing")
    }

    private func dotRow(activeIndex: Int?) -> some View {
        HStack(spacing: spacing) {
            ForEach(0..<3, id: \.self) { index in
                let isActive = activeIndex == index
                Circle()
                    .fill(isActive ? accent.opacity(0.9) : theme.mutedForeground.opacity(0.34))
                    .frame(width: dotSize, height: dotSize)
                    .offset(y: isActive ? -1.2 : 0)
                    .blur(radius: isActive ? 0.2 : 0)
                    .shadow(
                        color: isActive ? accent.opacity(0.26) : .clear,
                        radius: isActive ? 4 : 0
                    )
            }
        }
        .animation(.easeInOut(duration: 0.18), value: activeIndex)
    }
}

struct AssistantComposerOuterHalo: View {
    let style: AssistantComposerHaloStyle?
    let accent: Color
    let cornerRadius: CGFloat
    let animatesContinuously: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var activationProgress: CGFloat = 0

    init(
        style: AssistantComposerHaloStyle?,
        accent: Color,
        cornerRadius: CGFloat = 999,
        animatesContinuously: Bool = true
    ) {
        self.style = style
        self.accent = accent
        self.cornerRadius = cornerRadius
        self.animatesContinuously = animatesContinuously
    }

    var body: some View {
        Group {
            if let style {
                Group {
                    if reduceMotion || !animatesContinuously {
                        haloLayers(style: style, phase: staticPhase(for: style))
                    } else {
                        TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { context in
                            let elapsed = context.date.timeIntervalSinceReferenceDate
                            let phase = elapsed.truncatingRemainder(dividingBy: 4.6) / 4.6 * 360
                            haloLayers(style: style, phase: phase)
                        }
                    }
                }
                .opacity(Double(activationProgress))
                .blur(radius: (1 - activationProgress) * 6)
                .scaleEffect(
                    x: 0.96 + (activationProgress * 0.04),
                    y: 0.88 + (activationProgress * 0.12)
                )
                .allowsHitTesting(false)
            }
        }
        .onAppear {
            syncActivationProgress(isActive: style != nil, animated: false)
        }
        .onChange(of: style) { _, newStyle in
            syncActivationProgress(isActive: newStyle != nil, animated: true)
        }
    }

    private func haloLayers(style: AssistantComposerHaloStyle, phase: Double) -> some View {
        let gradient = AngularGradient(
            colors: style.palette(accent: accent),
            center: .center,
            startAngle: .degrees(phase),
            endAngle: .degrees(phase + 360)
        )

        return ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(gradient, lineWidth: style.lineWidth)
                .blur(radius: 1.1)
                .opacity(style.strokeOpacity)
                .padding(-1)

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(gradient, lineWidth: style.lineWidth * 2.8)
                .blur(radius: style.primaryBlurRadius)
                .opacity(style.primaryOpacity)
                .padding(-style.expansion * 0.45)
                .blendMode(.screen)

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(gradient, lineWidth: style.lineWidth * 5.2)
                .blur(radius: style.secondaryBlurRadius)
                .opacity(style.secondaryOpacity)
                .padding(-style.expansion)
                .blendMode(.plusLighter)
        }
    }

    private func staticPhase(for style: AssistantComposerHaloStyle) -> Double {
        switch style.tone {
        case .cool:
            42
        case .warm:
            198
        }
    }

    private func syncActivationProgress(isActive: Bool, animated: Bool) {
        let nextValue: CGFloat = isActive ? 1 : 0
        guard activationProgress != nextValue else { return }
        let phase: AssistantComposerStatusPhase = isActive ? .analyzing : .idle
        if animated {
            withAnimation(AssistantComposerWarmup.animation(for: phase)) {
                activationProgress = nextValue
            }
        } else {
            activationProgress = nextValue
        }
    }
}

private enum AssistantToolbarAskBarMetrics {
    static let minHeight: CGFloat = 28
    static let stopBallSize: CGFloat = 22
}

struct AssistantToolbarAskBar<Leading: View>: View {
    @Binding var text: String

    let placeholder: String
    let phase: AssistantComposerStatusPhase
    let theme: EpistemosTheme
    let accent: Color
    let isStreaming: Bool
    let fieldWidth: CGFloat?
    let font: Font
    let chromeTuning: AssistantToolbarAskBarChromeTuning
    let onSubmit: () -> Void
    let onStop: () -> Void
    let leading: () -> Leading

    init(
        text: Binding<String>,
        placeholder: String,
        phase: AssistantComposerStatusPhase,
        theme: EpistemosTheme,
        accent: Color,
        isStreaming: Bool,
        fieldWidth: CGFloat? = nil,
        font: Font = .system(size: 12),
        chromeTuning: AssistantToolbarAskBarChromeTuning = .standard,
        onSubmit: @escaping () -> Void,
        onStop: @escaping () -> Void,
        @ViewBuilder leading: @escaping () -> Leading
    ) {
        _text = text
        self.placeholder = placeholder
        self.phase = phase
        self.theme = theme
        self.accent = accent
        self.isStreaming = isStreaming
        self.fieldWidth = fieldWidth
        self.font = font
        self.chromeTuning = chromeTuning
        self.onSubmit = onSubmit
        self.onStop = onStop
        self.leading = leading
    }

    private var haloStyle: AssistantComposerHaloStyle? {
        AssistantComposerHaloStyle.resolve(for: phase)?.adjusted(for: chromeTuning)
    }

    private var fillColor: Color {
        switch phase {
        case .idle:
            theme.resolved.foreground.color.opacity(0.035)
        case .analyzing:
            accent.opacity(0.10)
        case .typing:
            accent.opacity(0.05)
        }
    }

    private var strokeColor: Color {
        switch phase {
        case .idle:
            theme.resolved.foreground.color.opacity(0.08)
        case .analyzing:
            accent.opacity(0.22)
        case .typing:
            accent.opacity(0.12)
        }
    }

    private var outlineStrokeColor: Color {
        strokeColor.opacity(chromeTuning.borderOpacityMultiplier)
    }

    private var surfaceShadowColor: Color {
        Color.black.opacity(theme.isDark ? chromeTuning.surfaceShadowOpacity : chromeTuning.surfaceShadowOpacity * 0.72)
    }

    private var outlineShadowColor: Color {
        Color.black.opacity(theme.isDark ? chromeTuning.outlineShadowOpacity : chromeTuning.outlineShadowOpacity * 0.7)
    }

    private var labelState: AssistantComposerStatusLabelState? {
        AssistantComposerStatusLabelState.resolve(
            inputText: text,
            phase: phase,
            idleText: placeholder
        )
    }

    var body: some View {
        HStack(spacing: 8) {
            leading()

            TextField("", text: $text)
                .textFieldStyle(.plain)
                .font(font)
                .foregroundStyle(theme.resolved.foreground.color.opacity(0.94))
                .tint(accent)
                .onSubmit {
                    onSubmit()
                }
                .overlay(alignment: .leading) {
                    if let labelState {
                        AssistantAnimatedStatusLabel(
                            state: labelState,
                            accent: accent,
                            phase: phase,
                            theme: theme,
                            font: font,
                            haloStyle: haloStyle
                        )
                    }
                }
                .overlay(alignment: .leading) {
                    if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, labelState == nil {
                        Text(placeholder)
                            .font(font)
                            .foregroundStyle(theme.resolved.foreground.color.opacity(0.48))
                            .allowsHitTesting(false)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(width: fieldWidth, alignment: .leading)

            if isStreaming {
                Button(action: onStop) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(theme.error)
                        .frame(
                            width: AssistantToolbarAskBarMetrics.stopBallSize,
                            height: AssistantToolbarAskBarMetrics.stopBallSize
                        )
                        .background(
                            Circle()
                                .fill(theme.resolved.background.color.opacity(theme.isDark ? 0.88 : 0.94))
                        )
                        .overlay(
                            Circle()
                                .strokeBorder(theme.error.opacity(0.28), lineWidth: 0.8)
                        )
                        .shadow(color: theme.error.opacity(0.18), radius: 6)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(minHeight: AssistantToolbarAskBarMetrics.minHeight)
        .padding(.horizontal, 10)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(fillColor)
                .shadow(
                    color: surfaceShadowColor,
                    radius: chromeTuning.surfaceShadowRadius,
                    y: chromeTuning.surfaceShadowYOffset
                )
        )
        .overlay(
            Capsule()
                .strokeBorder(outlineStrokeColor, lineWidth: chromeTuning.borderLineWidth)
                .shadow(
                    color: outlineShadowColor,
                    radius: chromeTuning.outlineShadowRadius,
                    y: chromeTuning.outlineShadowYOffset
                )
        )
        .background {
            AssistantComposerOuterHalo(style: haloStyle, accent: accent)
        }
        .compositingGroup()
        .shadow(
            color: accent.opacity(phase == .analyzing ? 0.18 : 0.10),
            radius: phase == .analyzing ? 10 : 6
        )
        .zIndex(phase == .idle ? 0 : 1)
    }
}
