import SwiftUI

enum GraphSurfacePresentation: Equatable {
    case overlay
    case embeddedHome

    var isEmbeddedHome: Bool { self == .embeddedHome }
}

// UAS: graph/embedded-route-metrics
// Plane: RuntimePlane::UI
// Residency: ResidencyTier::CurrentApp
enum EmbeddedGraphRouteMetrics {
    static let routeCornerRadius: CGFloat = 28
    static let borderWidth: CGFloat = 0.75
}

private struct GraphSurfacePresentationKey: EnvironmentKey {
    static let defaultValue: GraphSurfacePresentation = .overlay
}

extension EnvironmentValues {
    var graphSurfacePresentation: GraphSurfacePresentation {
        get { self[GraphSurfacePresentationKey.self] }
        set { self[GraphSurfacePresentationKey.self] = newValue }
    }
}

struct GraphWorkspaceContainer: View {
    @Environment(GraphState.self) private var graphState
    @Environment(UIState.self) private var ui
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.graphSurfacePresentation) private var graphSurfacePresentation

    private var theme: EpistemosTheme {
        graphSurfacePresentation.isEmbeddedHome
            ? ui.theme.surfaceVariant(.landing)
            : ui.theme
    }

    var body: some View {
        // 2026-05-19 — the shape-blur boundary used to live here, but on
        // the .canvas route this whole container's host view is hidden by
        // HologramOverlay's routeObserver. Moved to `ShapedGraphBoundaryHost`
        // mounted as a separate always-visible NSHostingView on the overlay
        // so the shape-blur is also visible while the user is on the canvas.
        routeContent
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .modifier(EmbeddedGraphRouteChrome(
            isEnabled: graphSurfacePresentation.isEmbeddedHome,
            theme: theme
        ))
        .animation(
            graphSurfacePresentation.isEmbeddedHome ? nil :
                (reduceMotion ? nil : .snappy(duration: 0.3, extraBounce: 0.1)),
            value: graphState.currentRoute
        )
    }

    @ViewBuilder
    private var graphPageBackdrop: some View {
        if graphSurfacePresentation.isEmbeddedHome {
            embeddedPageSurface
                .ignoresSafeArea()
                .allowsHitTesting(true)
        } else {
            // 2026-05-20: zero-copy backdrop — same pattern as graphNoteBackdrop.
            // Folder page inherits the graph window's existing NSVisualEffectView
            // blur (set up in HologramOverlay) instead of stacking its own
            // unifiedFrostedGlass on top. One blur = one compositing pass per
            // frame. Required for 120 FPS on the folder route.
            Color.clear
                .ignoresSafeArea()
                .allowsHitTesting(true)
        }
    }

    @ViewBuilder
    private var routeContent: some View {
        switch graphState.currentRoute {
        case .canvas:
            Color.clear
                .allowsHitTesting(false)

        case .note(let id):
            ZStack(alignment: .topLeading) {
                graphNoteBackdrop

                GraphNotePage(sourceId: id)
                    .id(id)
                    .background(pageContentBackground)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

        case .folder(let id):
            ZStack(alignment: .topLeading) {
                graphPageBackdrop

                VStack(spacing: 0) {
                    graphPageHeader(title: "Folder")

                    GraphFolderPage(folderId: id)
                        .id(id)
                        .background(pageContentBackground)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    @ViewBuilder
    private var graphNoteBackdrop: some View {
        if graphSurfacePresentation.isEmbeddedHome {
            embeddedPageSurface
                .ignoresSafeArea()
                .allowsHitTesting(true)
        } else {
            Color.clear
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }

    private var embeddedPageSurface: some View {
        Rectangle()
            .fill(theme.resolved.background.color)
    }

    @ViewBuilder
    private var pageContentBackground: some View {
        if graphSurfacePresentation.isEmbeddedHome {
            embeddedPageSurface
        } else {
            Color.clear
        }
    }

    @ViewBuilder
    private func graphPageHeader(title: String) -> some View {
        if graphSurfacePresentation.isEmbeddedHome {
            embeddedGraphPageHeader(title: title)
        } else {
            overlayGraphPageHeader(title: title)
        }
    }

    private func embeddedGraphPageHeader(title: String) -> some View {
        HStack(spacing: 8) {
            navButton(
                systemName: "chevron.backward",
                label: "Back",
                enabled: graphState.canGoBack
            ) {
                graphState.goBack()
            }

            navButton(
                systemName: "chevron.forward",
                label: "Forward",
                enabled: graphState.canGoForward
            ) {
                graphState.goForward()
            }

            Button {
                graphState.returnToCanvas()
            } label: {
                Label("Canvas", systemImage: "circle.grid.3x3.fill")
                    .font(.system(size: 13, weight: .medium))
                    .labelStyle(.titleAndIcon)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(theme.card.opacity(theme.isDark ? 0.82 : 0.92))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(theme.glassBorder.opacity(0.65), lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)
            .help("Return to graph canvas")

            Divider()
                .frame(height: 18)
                .opacity(0.3)
                .padding(.horizontal, 4)

            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .frame(height: 46)
        .background(theme.resolved.background.color)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(theme.glassBorder.opacity(theme.isDark ? 0.45 : 0.65))
                .frame(height: 0.5)
        }
    }

    private func overlayGraphPageHeader(title: String) -> some View {
        HStack(spacing: 8) {
            navButton(
                systemName: "chevron.backward",
                label: "Back",
                enabled: graphState.canGoBack
            ) {
                graphState.goBack()
            }

            navButton(
                systemName: "chevron.forward",
                label: "Forward",
                enabled: graphState.canGoForward
            ) {
                graphState.goForward()
            }

            Button {
                graphState.returnToCanvas()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "circle.grid.3x3.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Graph")
                        .font(.system(size: 13, weight: .medium))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                // 2026-05-20: zero-copy button chrome. Theme tint + thin
                // stroke instead of `.ultraThinMaterial` — this button
                // sits inside the graph window which already carries the
                // single NSVisualEffectView blur. Material here would be
                // a redundant blur kernel pass. See UnifiedFrostedGlass.swift
                // for the broader single-blur policy.
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(theme.glassBg.opacity(0.78))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(theme.glassBorder, lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)
            .help("Return to graph canvas")

            Spacer()

            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            Color.clear
                .frame(width: 160, height: 1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        // 2026-05-20 (revised): `nativeGlass: true` — opts the toolbar strip
        // into the macOS 26 native Liquid Glass shader. One optimized GPU
        // pass on top of the window's wallpaper blur. Reads as a real
        // native macOS toolbar instead of a flat tinted rectangle.
        .unifiedFrostedGlass(theme: theme, in: Rectangle(), nativeGlass: true)
    }

    @ViewBuilder
    private func navButton(
        systemName: String,
        label: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 26, height: 22)
                // 2026-05-20: zero-copy button chrome — see Graph button
                // above. Tint + stroke instead of `.ultraThinMaterial`.
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(theme.glassBg.opacity(0.78))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(theme.glassBorder, lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1.0 : 0.35)
        .help(label)
    }
}

// UAS: graph/embedded-route-chrome
// Plane: RuntimePlane::UI
// Residency: ResidencyTier::CurrentApp
private struct EmbeddedGraphRouteChrome: ViewModifier {
    let isEnabled: Bool
    let theme: EpistemosTheme

    func body(content: Content) -> some View {
        if isEnabled {
            let shape = RoundedRectangle(
                cornerRadius: EmbeddedGraphRouteMetrics.routeCornerRadius,
                style: .continuous
            )

            content
                .clipShape(shape)
                .overlay(
                    shape.strokeBorder(
                        theme.glassBorder.opacity(theme.isDark ? 0.72 : 0.58),
                        lineWidth: EmbeddedGraphRouteMetrics.borderWidth
                    )
                )
                .contentShape(shape)
        } else {
            content
        }
    }
}
