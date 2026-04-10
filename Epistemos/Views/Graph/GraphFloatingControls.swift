import SwiftUI

// MARK: - GraphFloatingControls
// Minimal floating pill bar at the bottom of the hologram overlay.
// Overlay stays global-only for now; page-mode logic remains elsewhere for
// embedded-graph work later.

enum GraphOverlayControlsDisplay {
    static let filterTypes: [GraphNodeType] = GraphNodeType.visibleCases.filter {
        $0 != .tag && $0 != .source && $0 != .quote
    }
    static let excludedFilterTypes = Set(GraphNodeType.visibleCases).subtracting(filterTypes)
    static let showsPageModeToggle = GraphOverlayModePolicy.pageModeEnabled
}

struct GraphFloatingControls: View {
    @Environment(GraphState.self) private var graphState

    @State private var showForceSettings = false

    var body: some View {
        HStack(spacing: 10) {
            physicsToggle

            forceSettingsButton

            minimizeButton

            resetViewButton

            Divider()
                .frame(height: 20)
                .opacity(0.3)

            rebuildGraphButton

            Divider()
                .frame(height: 20)
                .opacity(0.3)

            closeButton
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .glassEffect(.regular.interactive(), in: Capsule())
        .overlay(Capsule().strokeBorder(.primary.opacity(0.08), lineWidth: 0.5))
        .fixedSize(horizontal: true, vertical: false)
        .onAppear(perform: enforceDefaultFilters)
    }

    // MARK: - Default Filter Enforcement
    // Manual filter toggling was removed — users no longer control node-type visibility.
    // This enforces the canonical default: show the 5 visible types, hide tag/source/quote.
    private func enforceDefaultFilters() {
        var changed = false
        // Ensure all 5 visible types are on.
        for type in GraphOverlayControlsDisplay.filterTypes
            where !graphState.filter.activeNodeTypes.contains(type) {
            graphState.filter.toggleType(type)
            changed = true
        }
        // Ensure the 3 excluded types (tag/source/quote) stay off.
        for type in GraphOverlayControlsDisplay.excludedFilterTypes
            where graphState.filter.activeNodeTypes.contains(type) {
            graphState.filter.toggleType(type)
            changed = true
        }
        if changed {
            graphState.requestFilterSync()
        }
    }

    // MARK: - Physics Toggle

    private var physicsToggle: some View {
        let frozen = graphState.isPhysicsFrozen
        return ExpandingModeButton(
            title: "Freeze",
            systemImage: frozen ? "play.circle.fill" : "pause.circle.fill",
            isActive: frozen,
            activeTitle: "Resume",
            variant: .toolbar,
            helpText: frozen ? "Resume Physics" : "Freeze Physics",
            stableWidth: NativeControlSystem.reservedWidth(
                for: ["Freeze", "Resume"],
                variant: .toolbar
            )
        ) {
            graphState.isPhysicsFrozen.toggle()
            graphState.physicsFrozenVersion += 1
            graphState.savePhysicsSettings()
        }
        .accessibilityLabel(frozen ? "Resume physics simulation" : "Freeze physics simulation")
    }

    // MARK: - Force Settings

    private var forceSettingsButton: some View {
        AnchoredPopoverButton(
            title: "Forces",
            systemImage: "slider.horizontal.3",
            isPresented: $showForceSettings,
            variant: .toolbar,
            helpText: "Force Settings",
            accessibilityLabel: "Force settings",
            idealPopoverWidth: GraphForceSettingsLayout.panelWidth,
            contentPadding: 0,
            stableWidth: NativeControlSystem.reservedWidth(
                for: "Forces",
                variant: .toolbar,
                includesDisclosureGlyph: true
            )
        ) {
            GraphForceSettings()
                .environment(graphState)
        }
    }

    // MARK: - Minimize

    private var minimizeButton: some View {
        ToolbarCapsuleButton(
            title: nil,
            systemImage: "rectangle.compress.vertical",
            variant: .toolbar,
            helpText: "Minimize to floating window",
            accessibilityLabel: "Minimize to floating window"
        ) {
            NotificationCenter.default.post(name: .graphMinimizeRequested, object: nil)
        }
    }

    // MARK: - Reset View

    private var resetViewButton: some View {
        ToolbarCapsuleButton(
            title: nil,
            systemImage: "arrow.up.left.and.arrow.down.right",
            variant: .toolbar,
            helpText: "Zoom to fit",
            accessibilityLabel: "Zoom to fit"
        ) {
            NotificationCenter.default.post(name: .graphResetRequested, object: nil)
        }
    }

    // MARK: - Rebuild Graph

    private var rebuildGraphButton: some View {
        ToolbarCapsuleButton(
            title: nil,
            systemImage: "arrow.trianglehead.2.clockwise",
            variant: .toolbar,
            helpText: "Rebuild Graph",
            accessibilityLabel: "Rebuild graph"
        ) {
            graphState.requestGraphRebuild()
        }
    }

    // MARK: - Close

    private var closeButton: some View {
        ToolbarCapsuleButton(
            title: "Close",
            systemImage: "xmark",
            variant: .toolbar,
            role: .secondaryGhost,
            helpText: "Close Graph (Esc)",
            accessibilityLabel: "Close graph"
        ) {
            NotificationCenter.default.post(name: .graphCloseRequested, object: nil)
        }
    }
}

// MARK: - Color Extension

extension GraphNodeType {
    /// SwiftUI color matching the Rust renderer colors.
    var swiftUIColor: Color {
        switch self {
        case .note:     return Color(red: 0.39, green: 0.90, blue: 0.85)  // teal
        case .chat:     return Color(red: 1.00, green: 0.62, blue: 0.04)  // orange
        case .idea:     return Color(red: 1.00, green: 0.84, blue: 0.04)  // yellow
        case .source:   return Color(red: 0.20, green: 0.78, blue: 0.35)  // green
        case .folder:   return Color(red: 0.64, green: 0.52, blue: 0.37)  // brown
        case .quote:    return Color(red: 0.69, green: 0.32, blue: 0.87)  // purple
        case .tag:      return Color(red: 0.46, green: 0.46, blue: 0.50)  // gray
        case .block:    return Color(red: 0.55, green: 0.78, blue: 0.90)  // sky blue
        case .person:   return Color(red: 0.83, green: 0.35, blue: 0.58)  // rose
        case .project:  return Color(red: 0.89, green: 0.42, blue: 0.16)  // orange
        case .topic:    return Color(red: 0.20, green: 0.56, blue: 0.95)  // azure
        case .decision: return Color(red: 0.83, green: 0.20, blue: 0.18)  // red
        case .event:    return Color(red: 0.98, green: 0.56, blue: 0.27)  // coral
        case .resource: return Color(red: 0.14, green: 0.55, blue: 0.52)  // sea green
        }
    }
}
