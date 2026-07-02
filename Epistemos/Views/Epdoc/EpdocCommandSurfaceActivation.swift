import SwiftUI

@MainActor
struct EpdocCommandSurfaceActivation: View {
    let controller: EpdocEditorChromeController

    var body: some View {
        CommandWindowKeyObserver { isKey in
            if isKey {
                activate()
            } else {
                deactivate()
            }
        }
        .frame(width: 0, height: 0)
        .onAppear {
            CommandRegistrations.registerEpdocCommands()
        }
        .onDisappear(perform: deactivate)
    }

    private func activate() {
        CommandRegistry.shared.activateNoteSurface(
            id: ObjectIdentifier(controller),
            dispatch: { [weak controller] command in
                controller?.dispatch(command)
            },
            save: { [weak controller] in
                controller?.onSave()
            },
            showFindReplace: { [weak controller] in
                controller?.toolbarModel.isFindReplacePresented = true
            },
            state: { [weak controller] in
                guard let toolbar = controller?.toolbarModel else {
                    return EpistemosCommandSurfaceState()
                }
                return EpistemosCommandSurfaceState(
                    isDirty: toolbar.isDirty,
                    isBoldActive: toolbar.isBoldActive,
                    isItalicActive: toolbar.isItalicActive,
                    isStrikeActive: toolbar.isStrikeActive,
                    isCodeActive: toolbar.isCodeActive,
                    isHighlightActive: toolbar.isHighlightActive,
                    activeHeadingLevel: toolbar.activeHeadingLevel
                )
            }
        )
    }

    private func deactivate() {
        CommandRegistry.shared.deactivateNoteSurface(id: ObjectIdentifier(controller))
    }
}
