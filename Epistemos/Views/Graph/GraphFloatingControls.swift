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
        .glassEffect(.regular.interactive(), in: Capsule())
        .overlay(Capsule().strokeBorder(.primary.opacity(0.08), lineWidth: 0.5))
        .popover(isPresented: $showForceSettings, arrowEdge: .top) {
            GraphForceSettings()
                .environment(graphState)
        }
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
        Button {
            graphState.useSemanticClustering.toggle()
            if graphState.useSemanticClustering {
                graphState.computeSemanticClusters()
            } else {
                graphState.requestFilterSync()
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: graphState.useSemanticClustering ? "brain.head.profile.fill" : "brain.head.profile")
                    .font(.system(size: 10, weight: .medium))
                Text("Semantic")
                    .font(.system(size: 11, weight: .medium))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                graphState.useSemanticClustering ? Color.purple.opacity(0.25) : .clear,
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.primary.opacity(graphState.useSemanticClustering ? 1.0 : 0.5))
        .help(graphState.useSemanticClustering ? "Semantic Clustering On" : "Enable Semantic Clustering")
        .accessibilityLabel(graphState.useSemanticClustering ? "Semantic clustering on" : "Enable semantic clustering")
    }


    // MARK: - Physics Toggle

    private var physicsToggle: some View {
        let frozen = graphState.isPhysicsFrozen
        return Button {
            graphState.isPhysicsFrozen.toggle()
            graphState.physicsFrozenVersion += 1
            graphState.savePhysicsSettings()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: frozen ? "play.circle.fill" : "pause.circle.fill")
                    .font(.system(size: 10, weight: .medium))
                Text(frozen ? "Resume" : "Freeze")
                    .font(.system(size: 11, weight: .medium))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                frozen ? Color.teal.opacity(0.25) : .clear,
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.primary.opacity(frozen ? 1.0 : 0.5))
        .help(frozen ? "Resume Physics" : "Freeze Physics")
        .accessibilityLabel(frozen ? "Resume physics simulation" : "Freeze physics simulation")
    }

    // MARK: - Force Settings

    private var forceSettingsButton: some View {
        Button {
            showForceSettings.toggle()
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary.opacity(0.6))
                .frame(width: 28, height: 28)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help("Force Settings")
        .accessibilityLabel("Force settings")
    }

    // MARK: - Minimize

    private var minimizeButton: some View {
        Button {
            NotificationCenter.default.post(name: .graphMinimizeRequested, object: nil)
        } label: {
            Image(systemName: "rectangle.compress.vertical")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary.opacity(0.6))
                .frame(width: 28, height: 28)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help("Minimize to floating window")
        .accessibilityLabel("Minimize to floating window")
    }

    // MARK: - Reset View

    private var resetViewButton: some View {
        Button {
            NotificationCenter.default.post(name: .graphResetRequested, object: nil)
        } label: {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary.opacity(0.6))
                .frame(width: 28, height: 28)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help("Zoom to fit")
        .accessibilityLabel("Zoom to fit")
    }

    // MARK: - Rebuild Graph

    private var rebuildGraphButton: some View {
        Button {
            graphState.requestGraphRebuild()
        } label: {
            Image(systemName: "arrow.trianglehead.2.clockwise")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary.opacity(0.6))
                .frame(width: 28, height: 28)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help("Rebuild Graph")
        .accessibilityLabel("Rebuild graph")
    }

    // MARK: - Close

    private var closeButton: some View {
        Button {
            NotificationCenter.default.post(name: .graphCloseRequested, object: nil)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                Text("Close")
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(.primary.opacity(0.6))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help("Close Graph (Esc)")
        .accessibilityLabel("Close graph")
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
