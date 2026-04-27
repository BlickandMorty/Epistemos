import AppIntents
import Foundation
import OSLog

// MARK: - Cognitive App Intents (W11.1 / Phase 11.1)
//
// Wave 11.1 / compass §"ADA polish — App Intents + Spotlight": the
// 5 cognitive intents the master plan / Doc 2 flagged as the biggest
// unexplored Apple-native moat. Each intent is registered with
// EpistemosShortcutsProvider so it surfaces from Spotlight (macOS 26
// surfaces App Intents directly) + Shortcuts + Siri. "Stops being an
// app I open and starts being part of how the Mac thinks with me."
//
// All intents are `openAppWhenRun = true` so the app comes forward
// to surface the cognitive operation; the intent itself does the
// minimal pre-work and hands off to the SwiftUI surface.

private let cogIntentLog = Logger(
    subsystem: "com.epistemos",
    category: "CognitiveIntents"
)

// MARK: - 1. CaptureBrainDump

struct CaptureBrainDumpIntent: AppIntent {
    static let title: LocalizedStringResource = "Capture Brain Dump"
    static let description = IntentDescription(
        "Open Epistemos and start a voice / typed brain dump that's auto-routed to the right context (current chat, current note, or the raw-thoughts archive)."
    )
    static let openAppWhenRun: Bool = true

    @Parameter(
        title: "Body",
        description: "Optional pre-typed text to capture. Leave blank to dictate.",
        default: ""
    )
    var body: String

    static var parameterSummary: some ParameterSummary {
        Summary("Capture brain dump \(\.$body)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        cogIntentLog.info("CaptureBrainDumpIntent fired (chars=\(body.count, privacy: .public))")
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            // Direct text path — capture immediately into the
            // quarantine archive. UI surface (open the inspector
            // showing the entry) is a follow-up SwiftUI commit.
            QuarantineArchive.shared.capture(
                body: trimmed,
                kind: .rawThought,
                anchor: nil
            )
        }
        return .result()
    }
}

// MARK: - 2. AttachThoughtToContext

struct AttachThoughtToContextIntent: AppIntent {
    static let title: LocalizedStringResource = "Attach Thought to Context"
    static let description = IntentDescription(
        "Capture a thought and bind it to whatever you're currently doing in Epistemos (active chat, open note, or running session)."
    )
    static let openAppWhenRun: Bool = true

    @Parameter(title: "Thought")
    var thought: String

    @Parameter(
        title: "Context kind",
        description: "Where to attach: chat, note, session, or agent",
        default: "chat"
    )
    var contextKind: String

    @Parameter(
        title: "Context ID",
        description: "Opaque ID of the surface (leave blank to use the focused one)",
        default: ""
    )
    var contextId: String

    static var parameterSummary: some ParameterSummary {
        Summary("Attach \(\.$thought) to \(\.$contextKind)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let cleaned = thought.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return .result() }
        let anchor: QuarantineAnchor? = contextId.isEmpty
            ? nil
            : QuarantineAnchor(contextKind: contextKind, contextId: contextId)
        QuarantineArchive.shared.capture(
            body: cleaned,
            kind: .rawThought,
            anchor: anchor
        )
        cogIntentLog.info(
            "AttachThoughtToContextIntent fired (context=\(contextKind, privacy: .public)/\(contextId, privacy: .public))"
        )
        return .result()
    }
}

// MARK: - 3. RecallActiveThesis

struct RecallActiveThesisIntent: AppIntent {
    static let title: LocalizedStringResource = "Recall Active Thesis"
    static let description = IntentDescription(
        "Read the current conversation's active thesis aloud (or display it). Surfaces what Epistemos thinks you're currently arguing for."
    )
    static let openAppWhenRun: Bool = false

    @Parameter(
        title: "Conversation ID",
        description: "Conversation to inspect (leave blank for the most recent one)",
        default: ""
    )
    var conversationId: String

    @Parameter(
        title: "Read aloud",
        description: "Speak the thesis using the system voice",
        default: true
    )
    var readAloud: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Recall active thesis from \(\.$conversationId)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let id = conversationId.isEmpty ? "current" : conversationId
        guard let state = ConversationStateClassifier.shared.currentState(for: id) else {
            return .result(dialog: IntentDialog("No active thesis recorded for that conversation yet."))
        }
        if readAloud {
            EpistemosSpeechSynthesizer.shared.speak(state.activeThesis)
        }
        return .result(dialog: IntentDialog(stringLiteral: state.activeThesis))
    }
}

// MARK: - 4. OpenRawThoughtSandbox

struct OpenRawThoughtSandboxIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Raw Thought Sandbox"
    static let description = IntentDescription(
        "Toggle Ambient Retrieval ON for the current conversation. The agent gains read-access to your quarantined raw thoughts; turn back off to return to deterministic mode."
    )
    static let openAppWhenRun: Bool = true

    @Parameter(
        title: "Conversation ID",
        description: "Conversation to toggle (leave blank for the most recent one)",
        default: ""
    )
    var conversationId: String

    @Parameter(
        title: "Enable",
        description: "true = unlock raw thoughts; false = lock them again",
        default: true
    )
    var enable: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Toggle raw-thought sandbox \(\.$enable) for \(\.$conversationId)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let id = conversationId.isEmpty ? "current" : conversationId
        AmbientRetrievalToggle.shared.setEnabled(enable, for: id)
        let dialog: IntentDialog = enable
            ? "Raw-thought sandbox ON. The agent can now see your quarantine."
            : "Raw-thought sandbox OFF. Back to deterministic mode."
        return .result(dialog: dialog)
    }
}

// MARK: - 5. DelegateToAgent

struct DelegateToAgentIntent: AppIntent {
    static let title: LocalizedStringResource = "Delegate to Agent"
    static let description = IntentDescription(
        "Open the agent inspector with a prompt pre-filled. The agent will pick up your structured context (active thesis, recent notes, current vault) automatically."
    )
    static let openAppWhenRun: Bool = true

    @Parameter(title: "Prompt")
    var prompt: String

    @Parameter(
        title: "Capability tier",
        description: "Routing hint: agent (cloud reasoning), local (on-device), readOnly (no tools)",
        default: "agent"
    )
    var capabilityTier: String

    static var parameterSummary: some ParameterSummary {
        Summary("Delegate \(\.$prompt) to \(\.$capabilityTier)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let cleaned = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return .result() }
        cogIntentLog.info(
            "DelegateToAgentIntent fired tier=\(self.capabilityTier, privacy: .public) chars=\(cleaned.count, privacy: .public)"
        )
        // Persist the request as a brain dump anchored to "agent" so
        // the chat surface picks it up on launch. The full agent-
        // inspector wire-up (load the prompt into the chat composer)
        // is a follow-up SwiftUI commit.
        QuarantineArchive.shared.capture(
            body: cleaned,
            kind: .rawThought,
            anchor: QuarantineAnchor(
                contextKind: "agent",
                contextId: capabilityTier
            )
        )
        return .result()
    }
}
