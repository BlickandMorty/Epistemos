import AppIntents

// MARK: - Epistemos Shortcuts Provider
// Discoverable Siri phrases (macOS limit) focused on notes, graph, and plain AI help.

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
            intent: AskAboutNotesIntent(),
            phrases: [
                "Ask \(.applicationName) about my notes",
                "What do my \(.applicationName) notes say",
            ],
            shortTitle: "Ask Notes",
            systemImageName: "text.bubble"
        )

        AppShortcut(
            intent: SummarizeNoteIntent(),
            phrases: [
                "Summarize my \(.applicationName) note",
                "Summarize in \(.applicationName)",
            ],
            shortTitle: "Summarize",
            systemImageName: "doc.text.magnifyingglass"
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

        AppShortcut(
            intent: DailyBriefingIntent(),
            phrases: [
                "Daily brief in \(.applicationName)",
                "Give me my daily brief in \(.applicationName)",
            ],
            shortTitle: "Daily Brief",
            systemImageName: "newspaper"
        )
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
            "No usable local model is available. Open Settings to install or select one."
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
