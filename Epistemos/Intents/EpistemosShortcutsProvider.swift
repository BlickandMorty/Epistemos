import AppIntents

// MARK: - Epistemos Shortcuts Provider
// Top 10 discoverable Siri phrases (macOS limit). Strategy: lead with intents
// no competitor has (AI analysis, research), then essentials.
// All 23 intents work in Shortcuts.app — this controls discoverability only.

struct EpistemosShortcutsProvider: AppShortcutsProvider {
    nonisolated(unsafe) static var appShortcuts: [AppShortcut] {

        // MARK: Only Lucid Can Do This

        AppShortcut(
            intent: DeepAnalyzeIntent(),
            phrases: [
                "Analyze this in \(.applicationName)",
                "Grade the evidence in \(.applicationName)",
            ],
            shortTitle: "Deep Analyze",
            systemImageName: "waveform.path.ecg"
        )

        AppShortcut(
            intent: ResearchTopicIntent(),
            phrases: [
                "Research this in \(.applicationName)",
                "Find papers in \(.applicationName)",
            ],
            shortTitle: "Research Topic",
            systemImageName: "text.book.closed"
        )

        AppShortcut(
            intent: FactCheckIntent(),
            phrases: [
                "Fact check in \(.applicationName)",
                "Check this claim in \(.applicationName)",
            ],
            shortTitle: "Fact Check",
            systemImageName: "checkmark.shield"
        )

        // MARK: Apple Intelligence Composable

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

        // MARK: AI Note Intelligence

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

        // MARK: Quick Workflows

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
            intent: FindGapsIntent(),
            phrases: [
                "Find gaps in \(.applicationName)",
                "What am I missing in \(.applicationName)",
            ],
            shortTitle: "Find Gaps",
            systemImageName: "exclamationmark.magnifyingglass"
        )

        // MARK: Daily Intelligence

        AppShortcut(
            intent: DailyBriefingIntent(),
            phrases: [
                "Daily brief in \(.applicationName)",
                "Give me my daily brief in \(.applicationName)",
            ],
            shortTitle: "Daily Brief",
            systemImageName: "newspaper"
        )

        // NOTE: FindConnectionsIntent, GenerateQuestionsIntent, OpenMiniChatIntent,
        // and MoveNoteToFolderIntent are available in Shortcuts.app but not listed
        // here due to the macOS 10-shortcut limit on AppShortcutsProvider.
    }
}

// MARK: - Intent Errors

enum IntentError: Error, CustomLocalizedStringResourceConvertible {
    case appNotReady
    case noActiveNote
    case noApiKey
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
        case .noApiKey:
            "No API key configured. Open Settings to add your key."
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
