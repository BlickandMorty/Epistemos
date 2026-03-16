import SwiftUI

// MARK: - GraphFloatingControls
// Minimal floating pill bar at the bottom of the hologram overlay.
// Overlay stays global-only for now; page-mode logic remains elsewhere for
// embedded-graph work later.

enum GraphOverlayControlsDisplay {
    static let filterTypes: [GraphNodeType] = GraphNodeType.visibleCases.filter { $0 != .tag }
    static let showsPageModeToggle = GraphOverlayModePolicy.pageModeEnabled
}

struct GraphFloatingControls: View {
    @Environment(GraphState.self) private var graphState

    @State private var showForceSettings = false

    var body: some View {
        ToolbarMorphHost(style: .graphBar, baseSurface: .strip) {
            HStack(spacing: 12) {
                typeFilterPills

                Divider()
                    .frame(height: 20)
                    .opacity(0.3)

                semanticClusterToggle

                Divider()
                    .frame(height: 20)
                    .opacity(0.3)

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
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    // MARK: - Type Filter Pills

    private var typeFilterPills: some View {
        HStack(spacing: 6) {
            ForEach(GraphOverlayControlsDisplay.filterTypes, id: \.rawValue) { type in
                FilterPill(
                    type: type,
                    isActive: graphState.filter.activeNodeTypes.contains(type),
                    action: {
                        graphState.filter.toggleType(type)
                        graphState.requestFilterSync()
                    }
                )
            }
        }
    }

    // MARK: - Semantic Clustering Toggle

    private var semanticClusterToggle: some View {
        ExpandingModeButton(
            title: "Semantic",
            systemImage: graphState.useSemanticClustering
                ? "brain.head.profile.fill" : "brain.head.profile",
            isActive: graphState.useSemanticClustering,
            variant: .toolbar,
            helpText: graphState.useSemanticClustering
                ? "Semantic Clustering On" : "Enable Semantic Clustering",
            asciiAnimation: .toolbarStatus,
            stableWidth: NativeControlSystem.reservedWidth(for: "Semantic", variant: .toolbar),
            morphID: GraphToolbarMorphID.semantic.rawValue
        ) {
            graphState.useSemanticClustering.toggle()
            if graphState.useSemanticClustering {
                graphState.computeSemanticClusters()
            } else {
                graphState.requestFilterSync()
            }
        }
        .accessibilityLabel(graphState.useSemanticClustering ? "Semantic clustering on" : "Enable semantic clustering")
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
            asciiAnimation: .toolbarStatus,
            stableWidth: NativeControlSystem.reservedWidth(
                for: ["Freeze", "Resume"],
                variant: .toolbar
            ),
            morphID: GraphToolbarMorphID.physics.rawValue
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
            idealPopoverWidth: GraphForceSettingsLayout.panelWidth,
            contentPadding: 0,
            stableWidth: NativeControlSystem.reservedWidth(
                for: "Forces",
                variant: .toolbar,
                includesDisclosureGlyph: true
            ),
            morphID: GraphToolbarMorphID.forceSettings.rawValue
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
            accessibilityLabel: "Minimize to floating window",
            morphID: GraphToolbarMorphID.minimize.rawValue
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
            accessibilityLabel: "Zoom to fit",
            morphID: GraphToolbarMorphID.resetView.rawValue
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
            accessibilityLabel: "Rebuild graph",
            morphID: GraphToolbarMorphID.rebuild.rawValue
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
            accessibilityLabel: "Close graph",
            morphID: GraphToolbarMorphID.close.rawValue
        ) {
            NotificationCenter.default.post(name: .graphCloseRequested, object: nil)
        }
    }
}

// MARK: - FilterPill

private struct FilterPill: View {
    @Environment(GraphState.self) private var graphState
    let type: GraphNodeType
    let isActive: Bool
    let action: () -> Void

    private var usesDepthPalette: Bool {
        graphState.visualTheme == .dialogue
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                if !usesDepthPalette {
                    Circle()
                        .fill(type.swiftUIColor)
                        .frame(width: 7, height: 7)
                }

                Text(type.displayName)
                    .font(.system(size: 10, weight: .medium))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                usesDepthPalette
                    ? (isActive ? Color.primary.opacity(0.15) : Color.primary.opacity(0.05))
                    : (isActive ? type.swiftUIColor.opacity(0.15) : Color.primary.opacity(0.05)),
                in: Capsule()
            )
            .foregroundStyle(Color.primary.opacity(isActive ? 1.0 : 0.35))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(type.displayName) filter \(isActive ? "on" : "off")")
    }
}

// MARK: - Color Extension

extension GraphNodeType {
    /// SwiftUI color matching the Rust renderer colors.
    var swiftUIColor: Color {
        switch self {
        case .note:   return Color(red: 0.39, green: 0.90, blue: 0.85)  // teal
        case .chat:   return Color(red: 1.00, green: 0.62, blue: 0.04)  // orange
        case .idea:   return Color(red: 1.00, green: 0.84, blue: 0.04)  // yellow
        case .source: return Color(red: 0.20, green: 0.78, blue: 0.35)  // green
        case .folder: return Color(red: 0.64, green: 0.52, blue: 0.37)  // brown
        case .quote:  return Color(red: 0.69, green: 0.32, blue: 0.87)  // purple
        case .tag:    return Color(red: 0.46, green: 0.46, blue: 0.50)  // gray
        case .block:  return Color(red: 0.55, green: 0.78, blue: 0.90)  // sky blue
        }
    }
}
