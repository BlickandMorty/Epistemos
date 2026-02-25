import SwiftUI

// MARK: - Toolbar Navigation
// Home stays in the main window. Notes and Library open separate windows.
// The toolbar shows all three for quick access.

struct SegmentedNavPicker: View {
    @Environment(UIState.self) private var ui
    @State private var showNotesBrowser = false

    var body: some View {
        HStack(spacing: 6) {
            toolbarButton("Home", icon: "house", isActive: ui.activePanel == .home) {
                ui.setActivePanel(.home)
            }
            toolbarButton("Notes", icon: "pencil.line", isActive: showNotesBrowser) {
                showNotesBrowser.toggle()
            }
            .popover(isPresented: $showNotesBrowser, arrowEdge: .bottom) {
                NotesBrowserView()
                    .frame(width: 320, height: 500)
            }
            toolbarButton("Library", icon: "books.vertical", isActive: false) {
                UtilityWindowManager.shared.show(.library)
            }
        }
    }

    private func toolbarButton(
        _ label: String, icon: String, isActive: Bool, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .font(.system(size: 12, weight: isActive ? .semibold : .regular))
        }
        .buttonStyle(.bordered)
        .tint(isActive ? .accentColor : .secondary)
    }
}
