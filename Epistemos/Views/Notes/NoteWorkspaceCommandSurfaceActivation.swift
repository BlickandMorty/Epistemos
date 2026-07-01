import SwiftUI

@MainActor
private final class NoteWorkspaceCommandSurfaceToken {}

@MainActor
struct NoteWorkspaceCommandSurfaceActivation: View {
    let activationKey: String
    let isActive: Bool
    let save: @MainActor () -> Void
    let showFind: @MainActor () -> Void

    @State private var token = NoteWorkspaceCommandSurfaceToken()
    @State private var windowIsKey = false

    var body: some View {
        CommandWindowKeyObserver { isKey in
            windowIsKey = isKey
            syncActivation(isKeyWindow: isKey, surfaceIsActive: isActive)
        }
        .frame(width: 0, height: 0)
        .onAppear {
            CommandRegistrations.registerEpdocCommands()
            syncActivation(isKeyWindow: windowIsKey, surfaceIsActive: isActive)
        }
        .onChange(of: isActive) { _, newValue in
            syncActivation(isKeyWindow: windowIsKey, surfaceIsActive: newValue)
        }
        .onChange(of: activationKey) { _, _ in
            syncActivation(isKeyWindow: windowIsKey, surfaceIsActive: isActive)
        }
        .onDisappear(perform: deactivate)
    }

    private func syncActivation(isKeyWindow: Bool, surfaceIsActive: Bool) {
        if isKeyWindow && surfaceIsActive {
            activate()
        } else {
            deactivate()
        }
    }

    private func activate() {
        CommandRegistrations.registerEpdocCommands()
        CommandRegistry.shared.activateNoteUtilitySurface(
            id: ObjectIdentifier(token),
            save: save,
            showFindReplace: showFind
        )
    }

    private func deactivate() {
        CommandRegistry.shared.deactivateNoteSurface(id: ObjectIdentifier(token))
    }
}
