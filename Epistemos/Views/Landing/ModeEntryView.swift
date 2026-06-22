import SwiftUI

/// VISIBLE SURFACES / two-mode ontology (owner §122/§194/§292-313): the reusable mode-entry EXPERIENCE that
/// composes the pieces built this session — `WorkspaceModePicker` (act/work selector) + `ModeEntryTitleView`
/// (greeting → backspace → typewrite mode name → reveal) over `WorkspaceModeSelection` (the persisted current
/// mode). Selecting a mode re-runs the entry transition for it. This is the composable surface the landing flow
/// mounts; the final landing placement + blur/page-reveal chrome are the owner-reviewed visual follow-on.
///
/// Verified at the CHECKPOINT build (per the CODE-MORE-BUILD-LESS cadence); this increment composes only
/// already-tested components, gated structurally.
struct ModeEntryView: View {
    let greeting: String
    /// Fired when the entry transition for the selected mode completes — the caller reveals that mode's UI.
    var onEntered: ((WorkspaceModeKind) -> Void)?

    @State private var mode: WorkspaceModeKind

    init(
        greeting: String = "Ready when you are",
        onEntered: ((WorkspaceModeKind) -> Void)? = nil
    ) {
        self.greeting = greeting
        self.onEntered = onEntered
        _mode = State(initialValue: WorkspaceModeSelection.current())
    }

    var body: some View {
        VStack(spacing: 16) {
            // Re-keying on `mode` restarts the transition when the user switches modes (greeting → that
            // mode's name), per the owner's "select → typewrite the mode name" spec.
            ModeEntryTitleView(greeting: greeting, mode: mode, onRevealed: { onEntered?(mode) })
                .id(mode)

            WorkspaceModePicker(mode: $mode)
                .frame(maxWidth: 220)
        }
    }
}
