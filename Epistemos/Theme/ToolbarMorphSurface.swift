import Observation
import SwiftUI

enum ToolbarMorphVisualState: Equatable {
    case collapsed
    case hovering
    case armed
    case expanding
    case expanded
    case nestedExpanded
    case transitioning
    case receding
}

enum ToolbarMorphAnimationMode: Equatable {
    case `static`
    case displayLinked
}

enum ToolbarMorphBaseSurface {
    case none
    case strip
}

struct ToolbarMorphSurfaceStyle: Equatable {
    let baseCornerRadius: CGFloat
    let overflowPadding: CGFloat
    let maxProtrusionDepth: CGFloat
    let lobeHorizontalExpansion: CGFloat
    let mergeRadius: CGFloat
    let strokeOpacityDark: Double
    let strokeOpacityLight: Double

    static let graphBar = ToolbarMorphSurfaceStyle(
        baseCornerRadius: 18,
        overflowPadding: 12,
        maxProtrusionDepth: 11,
        lobeHorizontalExpansion: 8,
        mergeRadius: 10,
        strokeOpacityDark: 0.09,
        strokeOpacityLight: 0.06
    )

    static let composerControls = ToolbarMorphSurfaceStyle(
        baseCornerRadius: 0,
        overflowPadding: 8,
        maxProtrusionDepth: 8,
        lobeHorizontalExpansion: 6,
        mergeRadius: 8,
        strokeOpacityDark: 0.08,
        strokeOpacityLight: 0.05
    )

    static let notePreviewStrip = ToolbarMorphSurfaceStyle(
        baseCornerRadius: 14,
        overflowPadding: 8,
        maxProtrusionDepth: 6,
        lobeHorizontalExpansion: 5,
        mergeRadius: 6,
        strokeOpacityDark: 0.07,
        strokeOpacityLight: 0.045
    )
}

enum GraphToolbarMorphID: String {
    case semantic = "graph.semantic"
    case physics = "graph.physics"
    case forceSettings = "graph.forceSettings"
    case minimize = "graph.minimize"
    case resetView = "graph.resetView"
    case rebuild = "graph.rebuild"
    case close = "graph.close"
}

enum MainChatToolbarMorphID: String {
    case attach = "chat.attach"
    case research = "chat.research"
    case researchOptions = "chat.researchOptions"
    case incognito = "chat.incognito"
}

enum LandingToolbarMorphID: String {
    case research = "landing.research"
    case researchOptions = "landing.researchOptions"
    case history = "landing.history"
}

enum NoteToolbarMorphID: String {
    case preview = "note.preview"
    case backlinks = "note.backlinks"
    case history = "note.history"
    case writingTools = "note.writingTools"
}

private struct ToolbarMorphSpringConfig {
    let frequency: CGFloat
    let dampingRatio: CGFloat
    let settleDistance: CGFloat
    let settleVelocity: CGFloat

    static let shell = ToolbarMorphSpringConfig(
        frequency: 8.6,
        dampingRatio: 0.86,
        settleDistance: 0.0015,
        settleVelocity: 0.02
    )

    static let emphasis = ToolbarMorphSpringConfig(
        frequency: 9.2,
        dampingRatio: 0.84,
        settleDistance: 0.0015,
        settleVelocity: 0.02
    )
}

private struct ToolbarAnimatedScalar {
    var value: CGFloat = 0
    var velocity: CGFloat = 0
    var target: CGFloat = 0

    mutating func setTarget(_ nextTarget: CGFloat) {
        target = min(max(nextTarget, 0), 1)
    }

    mutating func snapToTarget() {
        value = target
        velocity = 0
    }

    mutating func advance(deltaTime: CGFloat, config: ToolbarMorphSpringConfig) {
        guard deltaTime > 0 else { return }

        let angularFrequency = max(config.frequency, 0.01) * 2 * .pi
        let damping = 2 * config.dampingRatio * angularFrequency
        let acceleration = ((target - value) * angularFrequency * angularFrequency) - (damping * velocity)

        velocity += acceleration * deltaTime
        value = min(max(value + (velocity * deltaTime), 0), 1)

        if isSettled(using: config) {
            snapToTarget()
        }
    }

    func isSettled(using config: ToolbarMorphSpringConfig) -> Bool {
        abs(value - target) <= config.settleDistance && abs(velocity) <= config.settleVelocity
    }
}

@MainActor
@Observable
final class ToolbarMorphCoordinator {
    let coordinateSpaceID = UUID()
    var hoveredItem: String?
    var pressedItem: String?
    var activeItem: String?
    var expansionProgress: CGFloat = 0
    var morphProgress: CGFloat = 0
    var hoverAttraction: CGFloat = 0
    var revealProgress: CGFloat = 0
    var protrusionDepth: CGFloat = 0
    var labelSpread: CGFloat = 0
    var visualState: ToolbarMorphVisualState = .collapsed
    var itemFrames: [String: CGRect] = [:]

    private var activeItems = Set<String>()
    private var revealByItem: [String: CGFloat] = [:]
    private var expansionState = ToolbarAnimatedScalar()
    private var morphState = ToolbarAnimatedScalar()
    private var hoverState = ToolbarAnimatedScalar()
    private var revealState = ToolbarAnimatedScalar()
    private var protrusionState = ToolbarAnimatedScalar()
    private var labelSpreadState = ToolbarAnimatedScalar()
    private var emphasisStates: [String: ToolbarAnimatedScalar] = [:]
    private var lastFrameDate: Date?

    func setFrames(_ frames: [String: CGRect]) {
        #if DEBUG
        let interval = Log.appPerf.beginInterval("toolbarMorphFrameCollection")
        defer { Log.appPerf.endInterval("toolbarMorphFrameCollection", interval) }
        #endif
        itemFrames = frames
    }

    func setHovered(_ id: String, isHovered: Bool) {
        if isHovered {
            hoveredItem = id
        } else if hoveredItem == id {
            hoveredItem = nil
        }
        refreshDerivedState()
    }

    func setPressed(_ id: String, isPressed: Bool) {
        if isPressed {
            pressedItem = id
        } else if pressedItem == id {
            pressedItem = nil
        }
        refreshDerivedState()
    }

    func setActive(_ id: String, isActive: Bool) {
        if isActive {
            activeItems.insert(id)
        } else {
            activeItems.remove(id)
        }
        refreshDerivedState()
    }

    func setReveal(_ id: String, progress: CGFloat) {
        let clamped = min(max(progress, 0), 1)
        if clamped == 0 {
            revealByItem.removeValue(forKey: id)
        } else {
            revealByItem[id] = clamped
        }
        refreshDerivedState()
    }

    func clear(_ id: String) {
        if hoveredItem == id { hoveredItem = nil }
        if pressedItem == id { pressedItem = nil }
        activeItems.remove(id)
        revealByItem.removeValue(forKey: id)
        itemFrames.removeValue(forKey: id)
        refreshDerivedState()
    }

    func revealProgress(for id: String) -> CGFloat {
        revealByItem[id] ?? 0
    }

    func emphasisProgress(for id: String) -> CGFloat {
        emphasisStates[id]?.value ?? 0
    }

    func hasActiveSurface(for id: String) -> Bool {
        pressedItem == id || activeItems.contains(id)
    }

    func emphasizedItemIDs() -> [String] {
        emphasisStates
            .filter { _, state in
                state.target > ToolbarMorphSpringConfig.emphasis.settleDistance
                    || state.value > ToolbarMorphSpringConfig.emphasis.settleDistance
            }
            .map(\.key)
            .sorted()
    }

    func animationMode(reduceMotion: Bool, windowOccluded: Bool) -> ToolbarMorphAnimationMode {
        guard !reduceMotion, !windowOccluded else { return .static }
        if pressedItem != nil || hoveredItem != nil || !activeItems.isEmpty || hasUnsettledMotion() {
            return .displayLinked
        }
        return .static
    }

    func advanceAnimationFrame(
        to date: Date,
        reduceMotion: Bool,
        windowOccluded: Bool
    ) {
        #if DEBUG
        let interval = Log.appPerf.beginInterval("toolbarMorphAdvance")
        defer { Log.appPerf.endInterval("toolbarMorphAdvance", interval) }
        #endif

        if reduceMotion || windowOccluded {
            snapAnimatedStateToTargets()
            lastFrameDate = date
            pruneEmphasisStates()
            return
        }

        let deltaTime = CGFloat(
            min(
                max(lastFrameDate.map { date.timeIntervalSince($0) } ?? (1.0 / 60.0), 1.0 / 240.0),
                1.0 / 20.0
            )
        )
        lastFrameDate = date

        expansionState.advance(deltaTime: deltaTime, config: .shell)
        morphState.advance(deltaTime: deltaTime, config: .shell)
        hoverState.advance(deltaTime: deltaTime, config: .shell)
        revealState.advance(deltaTime: deltaTime, config: .shell)
        protrusionState.advance(deltaTime: deltaTime, config: .shell)
        labelSpreadState.advance(deltaTime: deltaTime, config: .shell)

        for id in Array(emphasisStates.keys) {
            var state = emphasisStates[id] ?? ToolbarAnimatedScalar()
            state.advance(deltaTime: deltaTime, config: .emphasis)
            emphasisStates[id] = state
        }

        syncAnimatedOutputs()
        pruneEmphasisStates()
    }

    private func refreshDerivedState() {
        activeItem = pressedItem ?? activeItems.sorted().first ?? hoveredItem

        let maxReveal = revealByItem.values.max() ?? 0
        revealState.setTarget(maxReveal)
        labelSpreadState.setTarget(maxReveal)
        hoverState.setTarget(hoveredItem == nil ? 0 : 1)

        if pressedItem != nil {
            visualState = activeItems.isEmpty ? .armed : .nestedExpanded
            expansionState.setTarget(1)
            morphState.setTarget(1)
            protrusionState.setTarget(1)
            refreshEmphasisTargets()
            return
        }

        if !activeItems.isEmpty {
            visualState = maxReveal > 0 ? .expanded : .transitioning
            let targetExpansion = max(0.72, maxReveal)
            expansionState.setTarget(targetExpansion)
            morphState.setTarget(targetExpansion)
            protrusionState.setTarget(targetExpansion)
            refreshEmphasisTargets()
            return
        }

        if hoveredItem != nil {
            visualState = maxReveal > 0 ? .hovering : .receding
            expansionState.setTarget(maxReveal)
            morphState.setTarget(maxReveal)
            protrusionState.setTarget(0)
            refreshEmphasisTargets()
            return
        }

        visualState = .collapsed
        expansionState.setTarget(0)
        morphState.setTarget(0)
        protrusionState.setTarget(0)
        labelSpreadState.setTarget(0)
        hoverState.setTarget(0)
        refreshEmphasisTargets()
    }

    private func refreshEmphasisTargets() {
        let emphasizedIDs = Set(activeItems).union(pressedItem.map { [$0] } ?? [])
        let knownIDs = Set(emphasisStates.keys).union(emphasizedIDs)

        for id in knownIDs {
            var state = emphasisStates[id] ?? ToolbarAnimatedScalar()

            if pressedItem == id {
                state.setTarget(1)
            } else if activeItems.contains(id) {
                state.setTarget(max(0.72, revealByItem[id] ?? 0))
            } else {
                state.setTarget(0)
            }

            emphasisStates[id] = state
        }
    }

    private func hasUnsettledMotion() -> Bool {
        !expansionState.isSettled(using: .shell)
            || !morphState.isSettled(using: .shell)
            || !hoverState.isSettled(using: .shell)
            || !revealState.isSettled(using: .shell)
            || !protrusionState.isSettled(using: .shell)
            || !labelSpreadState.isSettled(using: .shell)
            || emphasisStates.values.contains(where: { !$0.isSettled(using: .emphasis) })
    }

    private func snapAnimatedStateToTargets() {
        expansionState.snapToTarget()
        morphState.snapToTarget()
        hoverState.snapToTarget()
        revealState.snapToTarget()
        protrusionState.snapToTarget()
        labelSpreadState.snapToTarget()

        for id in Array(emphasisStates.keys) {
            var state = emphasisStates[id] ?? ToolbarAnimatedScalar()
            state.snapToTarget()
            emphasisStates[id] = state
        }

        syncAnimatedOutputs()
    }

    private func syncAnimatedOutputs() {
        expansionProgress = expansionState.value
        morphProgress = morphState.value
        hoverAttraction = hoverState.value
        revealProgress = revealState.value
        protrusionDepth = protrusionState.value
        labelSpread = labelSpreadState.value
    }

    private func pruneEmphasisStates() {
        emphasisStates = emphasisStates.filter { _, state in
            state.target > ToolbarMorphSpringConfig.emphasis.settleDistance
                || state.value > ToolbarMorphSpringConfig.emphasis.settleDistance
                || !state.isSettled(using: .emphasis)
        }
    }
}

private struct ToolbarMorphContext {
    let coordinator: ToolbarMorphCoordinator
    let coordinateSpaceID: UUID
}

private struct ToolbarMorphContextKey: EnvironmentKey {
    static let defaultValue: ToolbarMorphContext? = nil
}

extension EnvironmentValues {
    fileprivate var toolbarMorphContext: ToolbarMorphContext? {
        get { self[ToolbarMorphContextKey.self] }
        set { self[ToolbarMorphContextKey.self] = newValue }
    }
}

private struct ToolbarMorphFramesPreferenceKey: PreferenceKey {
    static let defaultValue: [String: CGRect] = [:]

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private struct ToolbarMorphItemModifier: ViewModifier {
    let id: String?
    let isActive: Bool
    let revealProgress: CGFloat

    @Environment(\.toolbarMorphContext) private var toolbarMorphContext

    func body(content: Content) -> some View {
        if let id, let toolbarMorphContext {
            content
                .background {
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: ToolbarMorphFramesPreferenceKey.self,
                            value: [id: proxy.frame(in: .named(toolbarMorphContext.coordinateSpaceID))]
                        )
                    }
                }
                .onAppear {
                    toolbarMorphContext.coordinator.setActive(id, isActive: isActive)
                    toolbarMorphContext.coordinator.setReveal(id, progress: revealProgress)
                }
                .onChange(of: isActive) { _, active in
                    toolbarMorphContext.coordinator.setActive(id, isActive: active)
                }
                .onChange(of: revealProgress) { _, progress in
                    toolbarMorphContext.coordinator.setReveal(id, progress: progress)
                }
                .onDisappear {
                    toolbarMorphContext.coordinator.clear(id)
                }
        } else {
            content
        }
    }
}

private struct ToolbarMorphInteractionSyncModifier: ViewModifier {
    let id: String?
    let isHovered: Bool
    let isPressed: Bool

    @Environment(\.toolbarMorphContext) private var toolbarMorphContext

    func body(content: Content) -> some View {
        if let id, let toolbarMorphContext {
            content
                .onAppear {
                    toolbarMorphContext.coordinator.setHovered(id, isHovered: isHovered)
                    toolbarMorphContext.coordinator.setPressed(id, isPressed: isPressed)
                }
                .onChange(of: isHovered) { _, hovering in
                    toolbarMorphContext.coordinator.setHovered(id, isHovered: hovering)
                }
                .onChange(of: isPressed) { _, pressed in
                    toolbarMorphContext.coordinator.setPressed(id, isPressed: pressed)
                }
                .onDisappear {
                    toolbarMorphContext.coordinator.setHovered(id, isHovered: false)
                    toolbarMorphContext.coordinator.setPressed(id, isPressed: false)
                }
        } else {
            content
        }
    }
}

extension View {
    func toolbarMorphItem(
        id: String?,
        isActive: Bool = false,
        revealProgress: CGFloat = 0
    ) -> some View {
        modifier(ToolbarMorphItemModifier(id: id, isActive: isActive, revealProgress: revealProgress))
    }

    func toolbarMorphInteractionSync(
        id: String?,
        isHovered: Bool,
        isPressed: Bool
    ) -> some View {
        modifier(
            ToolbarMorphInteractionSyncModifier(
                id: id,
                isHovered: isHovered,
                isPressed: isPressed
            )
        )
    }
}

struct ToolbarMorphHost<Content: View>: View {
    let style: ToolbarMorphSurfaceStyle
    let baseSurface: ToolbarMorphBaseSurface
    let content: Content

    @State private var coordinator = ToolbarMorphCoordinator()

    init(
        style: ToolbarMorphSurfaceStyle,
        baseSurface: ToolbarMorphBaseSurface,
        @ViewBuilder content: () -> Content
    ) {
        self.style = style
        self.baseSurface = baseSurface
        self.content = content()
    }

    var body: some View {
        content
            .coordinateSpace(name: coordinator.coordinateSpaceID)
            .environment(
                \.toolbarMorphContext,
                ToolbarMorphContext(
                    coordinator: coordinator,
                    coordinateSpaceID: coordinator.coordinateSpaceID
                )
            )
            .background {
                ToolbarMorphShell(
                    coordinator: coordinator,
                    style: style,
                    baseSurface: baseSurface,
                    shellPadding: style.overflowPadding
                )
                .padding(-style.overflowPadding)
            }
            .onPreferenceChange(ToolbarMorphFramesPreferenceKey.self) { frames in
                coordinator.setFrames(frames)
            }
    }
}

private struct ToolbarMorphShell: View {
    let coordinator: ToolbarMorphCoordinator
    let style: ToolbarMorphSurfaceStyle
    let baseSurface: ToolbarMorphBaseSurface
    let shellPadding: CGFloat

    @Environment(UIState.self) private var ui
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    private var usesTimeline: Bool {
        coordinator.animationMode(
            reduceMotion: reduceMotion,
            windowOccluded: ui.windowOccluded
        ) == .displayLinked
    }

    var body: some View {
        Group {
            if usesTimeline {
                TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                    canvasBody(at: timeline.date)
                }
            } else {
                canvasBody(at: Date())
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func canvasBody(at date: Date) -> some View {
        coordinator.advanceAnimationFrame(
            to: date,
            reduceMotion: reduceMotion,
            windowOccluded: ui.windowOccluded
        )

        return Canvas(opaque: false, rendersAsynchronously: true) { context, size in
            #if DEBUG
            let drawInterval = Log.appPerf.beginInterval("toolbarMorphCanvasDraw")
            defer { Log.appPerf.endInterval("toolbarMorphCanvasDraw", drawInterval) }
            #endif

            let snapshot = shellSnapshot(size: size)
            guard snapshot.shouldDraw else { return }

            if snapshot.useUnionFilters {
                context.addFilter(.alphaThreshold(min: 0.35, color: snapshot.fillColor))
                context.addFilter(.blur(radius: snapshot.mergeRadius))
                context.drawLayer { layer in
                    if let baseRect = snapshot.baseRect {
                        layer.fill(
                            roundedRectPath(baseRect, radius: style.baseCornerRadius),
                            with: .color(.black)
                        )
                    }

                    for rect in snapshot.protrusionRects {
                        layer.fill(
                            roundedRectPath(rect, radius: snapshot.protrusionCornerRadius),
                            with: .color(.black)
                        )
                    }
                }
            } else {
                if let baseRect = snapshot.baseRect {
                    context.fill(
                        roundedRectPath(baseRect, radius: style.baseCornerRadius),
                        with: .color(snapshot.fillColor)
                    )
                }

                for rect in snapshot.protrusionRects {
                    context.fill(
                        roundedRectPath(rect, radius: snapshot.protrusionCornerRadius),
                        with: .color(snapshot.fillColor)
                    )
                }
            }

            if let baseRect = snapshot.baseRect {
                context.stroke(
                    roundedRectPath(baseRect, radius: style.baseCornerRadius),
                    with: .color(snapshot.strokeColor),
                    lineWidth: snapshot.strokeWidth
                )
            }
        }
    }

    private func shellSnapshot(size: CGSize) -> ToolbarMorphSnapshot {
        #if DEBUG
        let interval = Log.appPerf.beginInterval("toolbarMorphSnapshot")
        defer { Log.appPerf.endInterval("toolbarMorphSnapshot", interval) }
        #endif

        let contentRect = CGRect(
            x: shellPadding,
            y: shellPadding,
            width: max(size.width - (shellPadding * 2), 0),
            height: max(size.height - (shellPadding * 2), 0)
        )

        let fillOpacityBase: Double = reduceTransparency
            ? (ui.theme.isDark ? 0.14 : 0.10)
            : (ui.theme.isDark ? 0.07 : 0.05)
        let fillOpacity = fillOpacityBase + (Double(coordinator.protrusionDepth) * 0.04)
        let strokeOpacity = ui.theme.isDark ? style.strokeOpacityDark : style.strokeOpacityLight
        let increasedContrast = colorSchemeContrast == .increased

        let protrusionRects = coordinator.emphasizedItemIDs().compactMap { id -> CGRect? in
            guard let frame = coordinator.itemFrames[id] else { return nil }
            let emphasis = coordinator.emphasisProgress(for: id)
            guard emphasis > 0 else { return nil }

            let verticalBoost = style.maxProtrusionDepth * emphasis
            let horizontalExpansion = style.lobeHorizontalExpansion * max(
                emphasis,
                coordinator.labelSpread * 0.35
            )

            return CGRect(
                x: frame.minX - horizontalExpansion + shellPadding,
                y: frame.minY - verticalBoost * 0.42 + shellPadding,
                width: frame.width + (horizontalExpansion * 2),
                height: frame.height + verticalBoost
            )
        }

        return ToolbarMorphSnapshot(
            shouldDraw: baseSurface == .strip || !protrusionRects.isEmpty,
            baseRect: baseSurface == .strip ? contentRect : nil,
            protrusionRects: protrusionRects,
            protrusionCornerRadius: baseSurface == .strip ? max(style.baseCornerRadius, 12) : 12,
            fillColor: ui.theme.foreground.opacity(fillOpacity),
            strokeColor: ui.theme.foreground.opacity(increasedContrast ? strokeOpacity * 1.6 : strokeOpacity),
            strokeWidth: increasedContrast ? 0.8 : 0.55,
            mergeRadius: reduceMotion ? 0 : style.mergeRadius * max(0.7, coordinator.morphProgress),
            useUnionFilters: !reduceMotion && !protrusionRects.isEmpty
        )
    }

    private func roundedRectPath(_ rect: CGRect, radius: CGFloat) -> Path {
        RoundedRectangle(cornerRadius: radius, style: .continuous).path(in: rect)
    }
}

private struct ToolbarMorphSnapshot {
    let shouldDraw: Bool
    let baseRect: CGRect?
    let protrusionRects: [CGRect]
    let protrusionCornerRadius: CGFloat
    let fillColor: Color
    let strokeColor: Color
    let strokeWidth: CGFloat
    let mergeRadius: CGFloat
    let useUnionFilters: Bool
}
