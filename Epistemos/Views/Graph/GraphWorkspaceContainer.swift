import SwiftUI
import SwiftData

struct GraphWorkspaceContainer: View {
    @Environment(GraphState.self) private var graphState
    @Environment(UIState.self) private var ui
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Injected by the surrounding HologramOverlayHostedViewBuilder
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ZStack {
            switch graphState.currentRoute {
            case .canvas:
                // While on .canvas the host NSHostingView is hidden by
                // HologramOverlay's routeObserver, so this branch is never
                // rendered in practice. Kept as a safe empty fallback.
                Color.clear
                    .allowsHitTesting(false)

            case .note(let id):
                graphPageBackdrop

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
        Rectangle()
            .fill(.ultraThinMaterial)
            .ignoresSafeArea()
            .allowsHitTesting(true)
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
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
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
        .background(.ultraThinMaterial)
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
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1.0 : 0.35)
        .help(label)
    }
}
