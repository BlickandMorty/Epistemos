import SwiftData
import SwiftUI

// Graph sidebar shell retained for graph navigation while the old graph-chat
// surface is removed. It intentionally has no composer, runtime picker, or
// chat submission path.
struct HologramSearchSidebar: View {
    @Environment(GraphState.self) private var graphState
    @Environment(UIState.self) private var ui

    let inspectorState: NodeInspectorState
    let modelContext: ModelContext?
    let onRevealNode: (UUID) -> Void

    init(
        inspectorState: NodeInspectorState,
        modelContext: ModelContext?,
        onRevealNode: @escaping (UUID) -> Void
    ) {
        self.inspectorState = inspectorState
        self.modelContext = modelContext
        self.onRevealNode = onRevealNode
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                Text("Graph")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                Spacer(minLength: 0)
            }

            if let selected = graphState.selectedNodeId.flatMap({ graphState.store.nodes[$0] }) {
                Button {
                    if let uuid = UUID(uuidString: selected.id) {
                        onRevealNode(uuid)
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(selected.label.isEmpty ? "Selected Node" : selected.label)
                            .lineLimit(1)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                        Text(selected.type.rawValue)
                            .lineLimit(1)
                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            } else {
                Text("Select a node to inspect it.")
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(width: 300, alignment: .topLeading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(ui.theme.border.opacity(0.5), lineWidth: 1)
        )
    }
}
