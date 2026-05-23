import SwiftUI
import SwiftData

struct GraphWorkspaceContainer: View {
    @Environment(GraphState.self) private var graphState
    @Environment(UIState.self) private var ui
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Injected by the surrounding HologramOverlayHostedViewBuilder
    @Environment(\.modelContext) private var modelContext

    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        // 2026-05-19 — the shape-blur boundary used to live here, but on
        // the .canvas route this whole container's host view is hidden by
        // HologramOverlay's routeObserver. Moved to `ShapedGraphBoundaryHost`
        // mounted as a separate always-visible NSHostingView on the overlay
        // so the shape-blur is also visible while the user is on the canvas.
        ZStack {
            switch graphState.currentRoute {
            case .canvas:
                Color.clear
                    .allowsHitTesting(false)

            case .note(let id):
                graphNoteBackdrop

                VStack(spacing: 0) {
                    graphPageHeader(title: "Note")

                    GraphNotePage(sourceId: id)
                        .id(id)
                }

            case .folder(let id):
                graphPageBackdrop

                VStack(spacing: 0) {
                    graphPageHeader(title: "Folder")

                    GraphFolderPage(folderId: id)
                        .id(id)
                }
            }
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.3, extraBounce: 0.1), value: graphState.currentRoute)
    }

    private var graphPageBackdrop: some View {
        // 2026-05-20: zero-copy backdrop — same pattern as graphNoteBackdrop.
        // Folder page inherits the graph window's existing NSVisualEffectView
        // blur (set up in HologramOverlay) instead of stacking its own
        // unifiedFrostedGlass on top. One blur = one compositing pass per
        // frame. Required for 120 FPS on the folder route.
        Color.clear
            .ignoresSafeArea()
            .allowsHitTesting(true)
    }

    private var graphNoteBackdrop: some View {
        Color.clear
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }

    private func graphPageHeader(title: String) -> some View {
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

            Color.clear.frame(width: 160, height: 1)
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
