import SwiftUI

// MARK: - GraphFloatingControls
// Minimal floating pill bar at the bottom of the hologram overlay.
// Contains: 7 type filter pills, Global/Page toggle, forces gear icon.
// Liquid Glass styling via .glassEffect().

struct GraphFloatingControls: View {
    @Environment(GraphState.self) private var graphState

    @State private var showForceSettings = false

    var body: some View {
        HStack(spacing: 12) {
            typeFilterPills

            Divider()
                .frame(height: 20)
                .opacity(0.3)

            modeToggle

            Divider()
                .frame(height: 20)
                .opacity(0.3)

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
        .overlay(Capsule().strokeBorder(.white.opacity(0.08), lineWidth: 0.5))
        .popover(isPresented: $showForceSettings, arrowEdge: .top) {
            GraphForceSettings()
                .environment(graphState)
        }
    }

    // MARK: - Type Filter Pills

    private var typeFilterPills: some View {
        HStack(spacing: 6) {
            ForEach(GraphNodeType.allCases, id: \.rawValue) { type in
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

    // MARK: - Mode Toggle

    private var modeToggle: some View {
        HStack(spacing: 4) {
            modeButton(label: "Global", icon: "globe", isSelected: isGlobalMode) {
                graphState.cleanupEphemeralNodes()
                graphState.clearFocus()
                graphState.mode = .global
                graphState.requestRecommit()
            }
            modeButton(label: "Page", icon: "doc", isSelected: !isGlobalMode) {
                if let selected = graphState.selectedNodeId {
                    graphState.mode = .page(nodeId: selected)
                    graphState.focusOnNode(selected, depth: 2)
                    graphState.requestRecommit()
                }
            }
        }
    }

    private var isGlobalMode: Bool {
        if case .global = graphState.mode { return true }
        return false
    }

    private func modeButton(label: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
                Text(label)
                    .font(.system(size: 11, weight: .medium))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isSelected ? .white.opacity(0.15) : .clear, in: Capsule())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? .white : .white.opacity(0.5))
    }

    // MARK: - Force Settings

    private var forceSettingsButton: some View {
        Button {
            showForceSettings.toggle()
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: 28, height: 28)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Minimize

    private var minimizeButton: some View {
        Button {
            graphState.pendingMinimize = true
        } label: {
            Image(systemName: "rectangle.compress.vertical")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: 28, height: 28)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help("Minimize to floating window")
    }

    // MARK: - Reset View

    private var resetViewButton: some View {
        Button {
            graphState.pendingResetView = true
        } label: {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: 28, height: 28)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help("Zoom to fit")
    }

    // MARK: - Rebuild Graph

    private var rebuildGraphButton: some View {
        Button {
            graphState.pendingRebuild = true
        } label: {
            Image(systemName: "arrow.trianglehead.2.clockwise")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: 28, height: 28)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help("Rebuild Graph")
    }

    // MARK: - Close

    private var closeButton: some View {
        Button {
            graphState.pendingClose = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                Text("Close")
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(.white.opacity(0.6))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help("Close Graph (Esc)")
    }
}

// MARK: - FilterPill

private struct FilterPill: View {
    let type: GraphNodeType
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Circle()
                    .fill(type.swiftUIColor)
                    .frame(width: 7, height: 7)

                Text(type.displayName)
                    .font(.system(size: 10, weight: .medium))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isActive ? type.swiftUIColor.opacity(0.15) : .white.opacity(0.05), in: Capsule())
            .foregroundStyle(isActive ? .white : .white.opacity(0.35))
        }
        .buttonStyle(.plain)
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
        }
    }
}
