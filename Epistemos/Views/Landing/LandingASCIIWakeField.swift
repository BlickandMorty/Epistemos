// LandingASCIIWakeField — a hidden ASCII field whose cursor WAKE reveals words from a
// vocabulary (fluid trail integrated into the landing's vector ontology). Revived from
// commit d3b73c05d (owner 2026-07-03); engine is pure + unit-tested.
import SwiftUI

struct LandingASCIIWakeTrail: Equatable {
    let x: CGFloat
    let y: CGFloat
    let startTime: TimeInterval
    let radiusScale: CGFloat

    init(x: CGFloat, y: CGFloat, startTime: TimeInterval, radiusScale: CGFloat = 1) {
        self.x = x
        self.y = y
        self.startTime = startTime
        self.radiusScale = radiusScale
    }

    init(column: Int, row: Int, startTime: TimeInterval, radiusScale: CGFloat = 1) {
        self.init(x: CGFloat(column), y: CGFloat(row), startTime: startTime, radiusScale: radiusScale)
    }
}

struct LandingASCIIWakeFieldConfiguration: Equatable {
    var interpolationStep: CGFloat = 0.4
    var duration: TimeInterval = 1.14
    var initialRadius: CGFloat = 0.62
    var maxRadius: CGFloat = 7.6
    var growthExponent: CGFloat = 1.18
    var peakProgress: CGFloat = 0.68
    var endRadius: CGFloat = 0.4
    var contractionExponent: CGFloat = 0.72
    var boundaryThickness: CGFloat = 1.15
    var scrambleCharacters = ASCIIRippleConfiguration().characters
    var surfaceCharacters: [Character] = Array(repeating: "·", count: 32)
    var restingSurfaceOpacity: Double = 0
    var maxTrailCount = 48  // owner 2026-07-04: was 176 — overlayText iterates every trail per
                            // frame, so a long trail lags/hangs on movement. Short subtle wake.
    var streamTailLength: CGFloat = 3.4
    var streamLongDragDistance: CGFloat = 4.8
    var streamVelocityReference: CGFloat = 26
    var streamCoreRadiusBoost: CGFloat = 0.72
    var streamAdaptiveStepBoost: CGFloat = 0.45
    var streamBubbleStride = 3
    var streamBubbleOffset: CGFloat = 1.15
    var streamBubbleBacktrack: CGFloat = 0.72
    var streamBubbleRadiusScale: CGFloat = 0.56
    var streamBubbleFastScaleBoost: CGFloat = 0.32
    var streamSwingMaxOffset: CGFloat = 0.72
    var streamSwingCycles: CGFloat = 1.18
    var streamHeadAgeBoost: TimeInterval = 0.1
}

struct LandingASCIIWakeFieldLayout: Equatable {
    struct CellPosition: Equatable {
        let column: Int
        let row: Int
    }

    let columns: Int
    let rows: Int
    let hiddenCharacters: [Character]
    let surfaceCharacters: [Character]
    let blankCharacters: [Character]
    let cellPositions: [CellPosition?]

    var hiddenText: String { String(hiddenCharacters) }
    var surfaceText: String { String(surfaceCharacters) }
    var blankText: String { String(blankCharacters) }
}

enum LandingASCIIWakeFieldEngine {
    struct TrailPoint: Equatable {
        let x: CGFloat
        let y: CGFloat
    }

    struct TrailSample: Equatable {
        let point: TrailPoint
        let radiusScale: CGFloat
        let ageOffset: TimeInterval

        init(point: TrailPoint, radiusScale: CGFloat, ageOffset: TimeInterval = 0) {
            self.point = point
            self.radiusScale = radiusScale
            self.ageOffset = ageOffset
        }
    }

    static func normalizedVocabulary(from values: [String]) -> [String] {
        var seen = Set<String>()
        var output: [String] = []

        for value in values {
            let trimmed = value
                .uppercased()
                .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let capped = String(trimmed.prefix(40))
            guard seen.insert(capped).inserted else { continue }
            output.append(capped)
        }

        if output.isEmpty {
            return ["EPISTEMOS", "RESEARCH", "KNOWLEDGE GRAPH", "NEW NOTE", "COMMAND PALETTE"]
        }

        return output
    }

    static func layout(
        vocabulary: [String],
        columns: Int,
        rows: Int,
        configuration: LandingASCIIWakeFieldConfiguration
    ) -> LandingASCIIWakeFieldLayout {
        let safeColumns = max(columns, 1)
        let safeRows = max(rows, 1)
        let requiredCells = safeColumns * safeRows
        let stream = Array((normalizedVocabulary(from: vocabulary).joined(separator: " · ") + " · "))
        let hiddenStream = stream.isEmpty ? Array("EPISTEMOS · ") : stream

        var hidden: [Character] = []
        hidden.reserveCapacity(requiredCells + safeRows - 1)

        var surface: [Character] = []
        surface.reserveCapacity(requiredCells + safeRows - 1)

        var blanks: [Character] = []
        blanks.reserveCapacity(requiredCells + safeRows - 1)

        var positions: [LandingASCIIWakeFieldLayout.CellPosition?] = []
        positions.reserveCapacity(requiredCells + safeRows - 1)

        var hiddenIndex = 0
        for row in 0..<safeRows {
            for column in 0..<safeColumns {
                hidden.append(hiddenStream[hiddenIndex % hiddenStream.count])
                surface.append(configuration.surfaceCharacters[(row * safeColumns + column) % configuration.surfaceCharacters.count])
                blanks.append(" ")
                positions.append(.init(column: column, row: row))
                hiddenIndex += 1
            }
            if row < safeRows - 1 {
                hidden.append("\n")
                surface.append("\n")
                blanks.append("\n")
                positions.append(nil)
            }
        }

        return LandingASCIIWakeFieldLayout(
            columns: safeColumns,
            rows: safeRows,
            hiddenCharacters: hidden,
            surfaceCharacters: surface,
            blankCharacters: blanks,
            cellPositions: positions
        )
    }

    static func hasActiveTrails(
        _ trails: [LandingASCIIWakeTrail],
        now: TimeInterval,
        configuration: LandingASCIIWakeFieldConfiguration
    ) -> Bool {
        for trail in trails where now - trail.startTime < configuration.duration {
            return true
        }
        return false
    }

    static func prunedTrails(
        _ trails: [LandingASCIIWakeTrail],
        now: TimeInterval,
        configuration: LandingASCIIWakeFieldConfiguration
    ) -> [LandingASCIIWakeTrail] {
        guard !trails.isEmpty else { return [] }

        var output: [LandingASCIIWakeTrail] = []
        output.reserveCapacity(trails.count)
        for trail in trails where now - trail.startTime < configuration.duration {
            output.append(trail)
        }
        return output
    }

    static func nextTrailCleanupDelay(
        _ trails: [LandingASCIIWakeTrail],
        now: TimeInterval,
        configuration: LandingASCIIWakeFieldConfiguration
    ) -> TimeInterval? {
        var nextDelay: TimeInterval?

        for trail in trails {
            let delay = trail.startTime + configuration.duration - now
            guard delay > 0 else { continue }
            if let currentDelay = nextDelay {
                if delay < currentDelay {
                    nextDelay = delay
                }
            } else {
                nextDelay = delay
            }
        }

        return nextDelay
    }

    static func interpolatedPath(
        from start: TrailPoint,
        to end: TrailPoint,
        maxStep: CGFloat = 0.4
    ) -> [TrailPoint] {
        let deltaX = end.x - start.x
        let deltaY = end.y - start.y
        let distance = sqrt(deltaX * deltaX + deltaY * deltaY)
        guard distance > 0 else { return [] }

        let steps = max(Int(ceil(distance / max(maxStep, 0.05))), 1)
        var output: [TrailPoint] = []
        output.reserveCapacity(steps)

        for step in 1...steps {
            let progress = CGFloat(step) / CGFloat(steps)
            let point = TrailPoint(
                x: start.x + deltaX * progress,
                y: start.y + deltaY * progress
            )
            if output.last != point {
                output.append(point)
            }
        }

        return output
    }

    static func streamInterpolationStep(
        distance: CGFloat,
        eventDelta: TimeInterval?,
        configuration: LandingASCIIWakeFieldConfiguration
    ) -> CGFloat {
        let intensity = streamIntensity(
            distance: distance,
            eventDelta: eventDelta,
            configuration: configuration
        )
        let baseStep = max(configuration.interpolationStep, 0.05)
        return baseStep * (1 + intensity * configuration.streamAdaptiveStepBoost)
    }

    static func streamPath(
        from start: TrailPoint,
        to end: TrailPoint,
        maxStep: CGFloat = 0.4,
        tailLength: CGFloat
    ) -> [TrailPoint] {
        let deltaX = end.x - start.x
        let deltaY = end.y - start.y
        let distance = sqrt(deltaX * deltaX + deltaY * deltaY)
        guard distance > 0 else { return [end] }

        let step = max(maxStep, 0.05)
        let normalizedX = deltaX / distance
        let normalizedY = deltaY / distance
        let tailSteps = max(Int(ceil(max(tailLength, 0) / step)), 0)
        let movementPoints = interpolatedPath(from: start, to: end, maxStep: step)
        var output: [TrailPoint] = []
        output.reserveCapacity(tailSteps + movementPoints.count + 1)

        if tailSteps > 0 {
            for stepIndex in stride(from: tailSteps, through: 1, by: -1) {
                let tailDistance = CGFloat(stepIndex) * step
                let point = TrailPoint(
                    x: end.x - normalizedX * tailDistance,
                    y: end.y - normalizedY * tailDistance
                )
                if output.last != point {
                    output.append(point)
                }
            }
        }

        for point in movementPoints {
            if output.last != point {
                output.append(point)
            }
        }
        if output.last != end {
            output.append(end)
        }

        return output
    }

    static func streamTrailSamples(
        from start: TrailPoint,
        to end: TrailPoint,
        eventDelta: TimeInterval? = nil,
        configuration: LandingASCIIWakeFieldConfiguration
    ) -> [TrailSample] {
        let deltaX = end.x - start.x
        let deltaY = end.y - start.y
        let distance = sqrt(deltaX * deltaX + deltaY * deltaY)
        guard distance > 0 else {
            return [.init(point: end, radiusScale: 1)]
        }

        let normalizedX = deltaX / distance
        let normalizedY = deltaY / distance
        let normalX = -normalizedY
        let normalY = normalizedX
        let intensity = streamIntensity(
            distance: distance,
            eventDelta: eventDelta,
            configuration: configuration
        )
        let interpolationStep = streamInterpolationStep(
            distance: distance,
            eventDelta: eventDelta,
            configuration: configuration
        )
        // Extend tail during intense drags to maintain water continuity
        let dynamicTailLength = configuration.streamTailLength * (1 + intensity * 0.5)
        let swingAmplitude = configuration.streamSwingMaxOffset * intensity
        let headAgeOffset = configuration.streamHeadAgeBoost * Double(intensity)
        let path = streamPath(
            from: start,
            to: end,
            maxStep: interpolationStep,
            tailLength: dynamicTailLength
        )
        var output: [TrailSample] = []
        output.reserveCapacity(path.count + path.count / max(configuration.streamBubbleStride, 1))

        let bubbleStride = max(configuration.streamBubbleStride, 2)
        var bubbleOrdinal = 0
        let progressDivisor = CGFloat(max(path.count - 1, 1))
        for (index, point) in path.enumerated() {
            let progress = CGFloat(index) / progressDivisor
            let swingTaper = sqrt(progress)
            let swing = sin(progress * .pi * configuration.streamSwingCycles) * swingAmplitude * swingTaper
            let streamPoint = TrailPoint(
                x: point.x + normalX * swing,
                y: point.y + normalY * swing
            )
            let streamRadiusScale = 1 + configuration.streamCoreRadiusBoost * intensity * progress
            let streamAgeOffset = headAgeOffset * Double(progress)

            if output.last?.point != streamPoint
                || output.last?.radiusScale != streamRadiusScale
                || output.last?.ageOffset != streamAgeOffset {
                output.append(
                    .init(
                        point: streamPoint,
                        radiusScale: streamRadiusScale,
                        ageOffset: streamAgeOffset
                    )
                )
            }

            guard index >= 2, index < path.count - 1, index.isMultiple(of: bubbleStride) else { continue }
            let side: CGFloat = bubbleOrdinal.isMultiple(of: 2) ? 1 : -1
            bubbleOrdinal += 1

            // Add swing to bubbles during intense movement for "water splash" effect
            let bubbleSwing = sin(progress * .pi * configuration.streamSwingCycles * 1.5) * swingAmplitude * 0.5 * intensity
            let bubblePoint = TrailPoint(
                x: streamPoint.x - normalizedX * configuration.streamBubbleBacktrack + normalX * side * configuration.streamBubbleOffset + normalX * bubbleSwing,
                y: streamPoint.y - normalizedY * configuration.streamBubbleBacktrack + normalY * side * configuration.streamBubbleOffset + normalY * bubbleSwing
            )
            // Ensure minimum bubble size during intense movement (prevents "tiny bubble" issue)
            let minBubbleScale: CGFloat = 0.4 + (intensity * 0.3)
            let bubbleRadiusScale = max(minBubbleScale, configuration.streamBubbleRadiusScale
                * (1 + configuration.streamBubbleFastScaleBoost * intensity))
            let bubbleAgeOffset = headAgeOffset * Double(max(progress - 0.1, 0))
            output.append(
                .init(
                    point: bubblePoint,
                    radiusScale: bubbleRadiusScale,
                    ageOffset: bubbleAgeOffset
                )
            )
        }

        return output
    }

    private static func streamIntensity(
        distance: CGFloat,
        eventDelta: TimeInterval?,
        configuration: LandingASCIIWakeFieldConfiguration
    ) -> CGFloat {
        let distanceFactor = min(max(distance / max(configuration.streamLongDragDistance, 0.1), 0), 1)
        guard let eventDelta else { return distanceFactor }

        let safeDelta = max(CGFloat(eventDelta), 1.0 / 240.0)
        let velocity = distance / safeDelta
        let velocityFactor = min(max(velocity / max(configuration.streamVelocityReference, 0.1), 0), 1)
        return max(distanceFactor, velocityFactor)
    }

    static func clampedTrailSamples(
        _ rawSamples: [TrailSample],
        columns: Int,
        rows: Int
    ) -> [TrailSample] {
        guard !rawSamples.isEmpty else { return [] }

        let maxColumn = CGFloat(max(columns - 1, 0))
        let maxRow = CGFloat(max(rows - 1, 0))
        var output: [TrailSample] = []
        output.reserveCapacity(rawSamples.count)

        for rawSample in rawSamples {
            let sample = TrailSample(
                point: TrailPoint(
                    x: max(0, min(maxColumn, rawSample.point.x)),
                    y: max(0, min(maxRow, rawSample.point.y))
                ),
                radiusScale: rawSample.radiusScale,
                ageOffset: rawSample.ageOffset
            )
            if output.last != sample {
                output.append(sample)
            }
        }

        return output
    }

    static func radius(
        progress: TimeInterval,
        configuration: LandingASCIIWakeFieldConfiguration
    ) -> CGFloat {
        let clamped = min(max(progress, 0), 1)
        let peak = min(max(configuration.peakProgress, 0.05), 0.95)

        if clamped <= peak {
            let normalized = CGFloat(clamped / peak)
            let shaped = pow(normalized, configuration.growthExponent)
            return configuration.initialRadius + shaped * (configuration.maxRadius - configuration.initialRadius)
        }

        let tailProgress = CGFloat((clamped - peak) / (1 - peak))
        let shaped = pow(tailProgress, configuration.contractionExponent)
        return configuration.maxRadius - shaped * (configuration.maxRadius - configuration.endRadius)
    }

    static func overlayText(
        layout: LandingASCIIWakeFieldLayout,
        now: TimeInterval,
        trails: [LandingASCIIWakeTrail],
        configuration: LandingASCIIWakeFieldConfiguration
    ) -> String {
        guard hasActiveTrails(trails, now: now, configuration: configuration) else {
            return layout.blankText
        }

        var output = layout.blankCharacters

        for index in layout.hiddenCharacters.indices {
            guard let position = layout.cellPositions[index] else { continue }
            let style = cellStyle(
                at: position,
                now: now,
                trails: trails,
                configuration: configuration
            )
            switch style {
            case .hidden:
                continue
            case .revealed:
                output[index] = layout.hiddenCharacters[index]
            case .scrambled(let scrambleIndex):
                output[index] = configuration.scrambleCharacters[scrambleIndex % configuration.scrambleCharacters.count]
            }
        }

        return String(output)
    }

    private enum CellStyle {
        case hidden
        case revealed
        case scrambled(Int)
    }

    private static func cellStyle(
        at position: LandingASCIIWakeFieldLayout.CellPosition,
        now: TimeInterval,
        trails: [LandingASCIIWakeTrail],
        configuration: LandingASCIIWakeFieldConfiguration
    ) -> CellStyle {
        var bestReveal = false
        var bestScramble: Int?
        var bestStrength: CGFloat = -.greatestFiniteMagnitude

        for trail in trails {
            let age = now - trail.startTime
            guard age >= 0, age < configuration.duration else { continue }

            let progress = age / configuration.duration
            let radius = radius(progress: progress, configuration: configuration) * trail.radiusScale
            let boundaryThickness = max(0.35, configuration.boundaryThickness * max(trail.radiusScale, 0.7))
            let scrambleShellThickness = max(boundaryThickness, radius * 0.15)
            let revealRadius = max(0, radius - scrambleShellThickness)
            let dx = CGFloat(position.column) - trail.x
            let dy = CGFloat(position.row) - trail.y
            let distance = sqrt(dx * dx + dy * dy)
            guard distance < radius else { continue }

            if distance >= revealRadius {
                let scrambleIndex = Int((distance - revealRadius) * 11) + Int(age / 0.035)
                let strength = radius - distance
                if strength > bestStrength {
                    bestStrength = strength
                    bestReveal = false
                    bestScramble = scrambleIndex
                }
            } else {
                let strength = revealRadius - distance
                if strength > bestStrength {
                    bestStrength = strength
                    bestReveal = true
                    bestScramble = nil
                }
            }
        }

        if bestReveal {
            return .revealed
        }
        if let bestScramble {
            return .scrambled(bestScramble)
        }
        return .hidden
    }
}

struct LandingASCIIWakeField: View {
    let vocabulary: [String]
    let theme: EpistemosTheme
    /// External cursor (landing-local). The landing backdrop is .allowsHitTesting(false),
    /// so this view's own .onContinuousHover never fires — the landing feeds the shared
    /// cursorLocation here instead so the wake still reveals words (owner 2026-07-04).
    var cursor: CGPoint? = nil

    @Environment(UIState.self) private var ui
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var layout = LandingASCIIWakeFieldLayout(
        columns: 1,
        rows: 1,
        hiddenCharacters: [" "],
        surfaceCharacters: ["·"],
        blankCharacters: [" "],
        cellPositions: [.init(column: 0, row: 0)]
    )
    @State private var trails: [LandingASCIIWakeTrail] = []
    @State private var lastHoverPoint: LandingASCIIWakeFieldEngine.TrailPoint?
    @State private var lastHoverTime: TimeInterval?
    @State private var trailCleanupTask: Task<Void, Never>?

    private let configuration = LandingASCIIWakeFieldConfiguration()
    private let fontSize: CGFloat = 11
    private let lineSpacing: CGFloat = 3

    private var charWidth: CGFloat { fontSize * 0.64 }
    private var lineHeight: CGFloat { fontSize + lineSpacing + 2 }
    private var shouldAnimate: Bool { !reduceMotion && !ui.windowOccluded }

    var body: some View {
        GeometryReader { proxy in
            let columns = max(Int(proxy.size.width / charWidth), 12)
            let rows = max(Int(proxy.size.height / lineHeight), 10)

            ZStack(alignment: .topLeading) {
                if configuration.restingSurfaceOpacity > 0 {
                    Text(layout.surfaceText)
                        .font(.system(size: fontSize, weight: .medium, design: .monospaced))
                        .lineSpacing(lineSpacing)
                        .foregroundStyle(theme.textTertiary.opacity(configuration.restingSurfaceOpacity))
                }

                if shouldAnimate, !trails.isEmpty {
                    TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { context in
                        Text(
                            LandingASCIIWakeFieldEngine.overlayText(
                                layout: layout,
                                now: context.date.timeIntervalSinceReferenceDate,
                                trails: trails,
                                configuration: configuration
                            )
                        )
                        .font(.system(size: fontSize, weight: .medium, design: .monospaced))
                        .lineSpacing(lineSpacing)
                        .foregroundStyle(theme.fontAccent.opacity(theme.isDark ? 0.10 : 0.09))  // owner 2026-07-04: barely visible — blend into the waves
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, 26)
            .padding(.vertical, 22)
            .mask(
                LinearGradient(
                    colors: [
                        .clear,
                        .white.opacity(0.9),
                        .white,
                        .white.opacity(0.9),
                        .clear,
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .contentShape(Rectangle())
            .onAppear {
                rebuildLayout(columns: columns, rows: rows)
            }
            .onChange(of: columns) { _, newValue in
                rebuildLayout(columns: newValue, rows: rows)
            }
            .onChange(of: rows) { _, newValue in
                rebuildLayout(columns: columns, rows: newValue)
            }
            .onChange(of: vocabulary) { _, _ in
                rebuildLayout(columns: columns, rows: rows)
            }
            .onContinuousHover { phase in
                switch phase {
                case .active(let location): registerHover(location, columns: columns, rows: rows)
                case .ended: endHover()
                }
            }
            // Owner 2026-07-04: the PRIMARY cursor path — the landing feeds cursorLocation
            // here because the backdrop is non-hit-testing (the hover above won't fire).
            .onChange(of: cursor) { _, newCursor in
                if let newCursor {
                    registerHover(newCursor, columns: columns, rows: rows)
                } else {
                    endHover()
                }
            }
            .onChange(of: shouldAnimate) { _, newValue in
                guard !newValue else { return }
                trails.removeAll(keepingCapacity: false)
                lastHoverPoint = nil
                lastHoverTime = nil
                trailCleanupTask?.cancel()
                trailCleanupTask = nil
            }
        }
        .onDisappear {
            trailCleanupTask?.cancel()
            trailCleanupTask = nil
        }
        .allowsHitTesting(true)
    }

    /// Turn a cursor position (view-local) into wake trail samples. Called from the
    /// external `cursor` feed (primary) and the local hover (fallback).
    private func registerHover(_ location: CGPoint, columns: Int, rows: Int) {
        guard shouldAnimate else { return }
        let point = LandingASCIIWakeFieldEngine.TrailPoint(
            x: max(0, min(CGFloat(columns - 1), (location.x - 26) / charWidth)),
            y: max(0, min(CGFloat(rows - 1), (location.y - 22) / lineHeight))
        )
        let now = Date.timeIntervalSinceReferenceDate
        // Throttle trail generation to ~25 Hz — fast cursor movement otherwise floods the
        // trail buffer that the overlay iterates every frame (owner 2026-07-04: lag/hang fix).
        if let lastHoverTime, now - lastHoverTime < 0.04 { return }
        if let lastHoverPoint, lastHoverPoint != point {
            let eventDelta = lastHoverTime.map { now - $0 }
            let rawSamples = LandingASCIIWakeFieldEngine.streamTrailSamples(
                from: lastHoverPoint, to: point, eventDelta: eventDelta, configuration: configuration)
            appendTrailSamples(rawSamples, now: now, columns: columns, rows: rows)
        } else if lastHoverPoint == nil {
            appendTrailSamples(
                [LandingASCIIWakeFieldEngine.TrailSample(point: point, radiusScale: 1)],
                now: now, columns: columns, rows: rows)
        }
        lastHoverPoint = point
        lastHoverTime = now
    }

    private func endHover() {
        lastHoverPoint = nil
        lastHoverTime = nil
    }

    private func appendTrailSamples(
        _ rawSamples: [LandingASCIIWakeFieldEngine.TrailSample],
        now: TimeInterval,
        columns: Int,
        rows: Int
    ) {
        let samples = LandingASCIIWakeFieldEngine.clampedTrailSamples(
            rawSamples,
            columns: columns,
            rows: rows
        )
        guard !samples.isEmpty else { return }

        trails = LandingASCIIWakeFieldEngine.prunedTrails(
            trails,
            now: now,
            configuration: configuration
        )

        let timeStride = min(0.01, configuration.duration / Double(max(samples.count * 5, 1)))
        trails.reserveCapacity(max(trails.count + samples.count, configuration.maxTrailCount))
        for (index, sample) in samples.enumerated() {
            trails.append(
                LandingASCIIWakeTrail(
                    x: sample.point.x,
                    y: sample.point.y,
                    startTime: now - timeStride * Double(samples.count - index - 1) - sample.ageOffset,
                    radiusScale: sample.radiusScale
                )
            )
        }
        if trails.count > configuration.maxTrailCount {
            trails.removeFirst(trails.count - configuration.maxTrailCount)
        }
        scheduleTrailCleanup()
    }

    private func rebuildLayout(columns: Int, rows: Int) {
        layout = LandingASCIIWakeFieldEngine.layout(
            vocabulary: vocabulary,
            columns: columns,
            rows: rows,
            configuration: configuration
        )
    }

    private func scheduleTrailCleanup() {
        trailCleanupTask?.cancel()

        let now = Date.timeIntervalSinceReferenceDate
        guard let delay = LandingASCIIWakeFieldEngine.nextTrailCleanupDelay(
            trails,
            now: now,
            configuration: configuration
        ) else {
            trailCleanupTask = nil
            return
        }

        trailCleanupTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(max(Int(ceil(delay * 1000)), 1)))
            guard !Task.isCancelled else { return }

            trails = LandingASCIIWakeFieldEngine.prunedTrails(
                trails,
                now: Date.timeIntervalSinceReferenceDate,
                configuration: configuration
            )

            if trails.isEmpty {
                trailCleanupTask = nil
            } else {
                scheduleTrailCleanup()
            }
        }
    }
}
