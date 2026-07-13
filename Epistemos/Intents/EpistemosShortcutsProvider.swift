import AppIntents

// MARK: - Epistemos Shortcuts Provider
// Free V1 discoverable Siri phrases focused on notes, search, and capture.

struct EpistemosShortcutsProvider: AppShortcutsProvider {
    nonisolated(unsafe) static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CreateNoteIntent(),
            phrases: [
                "Create a note in \(.applicationName)",
                "New note in \(.applicationName)",
            ],
            shortTitle: "Create Note",
            systemImageName: "note.text.badge.plus"
        )
        AppShortcut(
            intent: SystemSearchIntent(),
            phrases: [
                "Search \(.applicationName)",
                "Find in \(.applicationName)",
            ],
            shortTitle: "Search",
            systemImageName: "magnifyingglass"
        )
        AppShortcut(
            intent: QuickCaptureIntent(),
            phrases: [
                "Capture in \(.applicationName)",
                "Quick note in \(.applicationName)",
            ],
            shortTitle: "Quick Capture",
            systemImageName: "square.and.pencil"
        )
        // Brain dump is deterministic capture in Free V1; model-backed
        // analysis and agent shortcuts remain absent from this catalogue.
        AppShortcut(
            intent: CaptureBrainDumpIntent(),
            phrases: [
                "Capture a brain dump in \(.applicationName)",
                "Brain dump in \(.applicationName)",
            ],
            shortTitle: "Brain Dump",
            systemImageName: "brain.head.profile"
        )
        // NOTE: AttachThoughtToContextIntent is registered as an AppIntent
        // (still callable from Shortcuts.app + RemoteCallback) but excluded
        // from the AppShortcuts discoverable-phrases list because Apple
        // caps the AppShortcuts catalogue at 10 entries per app. The
        // CaptureBrainDumpIntent above subsumes the most common path
        // ("dump a thought into the right place"); attach-to-context is
        // a power-user op accessed via the Shortcuts editor explicitly.
    }
}

// MARK: - Intent Errors

enum IntentError: Error, CustomLocalizedStringResourceConvertible {
    case appNotReady
    case noActiveNote
    case noLocalModel
    case noVault
    case noteNotFound
    case analysisFailed
    case creationFailed

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .appNotReady:
            "Epistemos isn't ready yet. Please open the app first."
        case .noActiveNote:
            "No note is open. Open a note first, then try again."
        case .noLocalModel:
            "App-local generation has been removed. Use a connected provider surface for model-backed actions."
        case .noVault:
            "No vault is active. Open a vault folder first."
        case .noteNotFound:
            "That note couldn't be found."
        case .analysisFailed:
            "Analysis couldn't complete. Try again or check your connection."
        case .creationFailed:
            "Couldn't create the note. Check that a vault folder is active."
        }
    }
}
