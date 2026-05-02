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
    // W15 supportedModes migration: openAppWhenRun is deprecated on
    // macOS 26 in favour of IntentModes. We allow both .background
    // (zero-UI capture from Spotlight / Control Center / a Shortcut
    // pipeline) AND .foreground(.dynamic) (intent can escalate to
    // foreground if it wants to surface confirmation UI). The
    // perform() default path is headless so most invocations stay
    // background; only the optional UI-surface follow-up requires
    // the app to come forward.
    static let supportedModes: IntentModes = [.background, .foreground(.dynamic)]

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
    private static func activeContextAnchor() -> QuarantineAnchor? {
        guard let bootstrap = AppBootstrap.shared else { return nil }
        if let pageId = bootstrap.notesUI.activePageId {
            return QuarantineAnchor(contextKind: "note", contextId: pageId)
        }
        if let chatId = bootstrap.chatState.activeChatId {
            return QuarantineAnchor(contextKind: "chat", contextId: chatId)
        }
        return nil
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        cogIntentLog.info("CaptureBrainDumpIntent fired (chars=\(body.count, privacy: .public))")
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            NotificationCenter.default.post(name: .showQuickCapture, object: nil)
            _ = try? await donate()
            return .result(dialog: "Opening Quick Capture so you can dictate your brain dump.")
        }
        // Direct text path: capture immediately into the quarantine
        // archive, preserving the focused note/chat as an anchor.
        QuarantineArchive.shared.capture(
            body: trimmed,
            kind: .rawThought,
            anchor: Self.activeContextAnchor()
        )
        // Wave 14 — donate so Siri / Spotlight learn the user's
        // brain-dump cadence + surface this intent on the lock screen
        // / Siri SmartStack at the right time of day.
        _ = try? await donate()
        return .result(dialog: "Captured brain dump in Epistemos.")
    }
}

// MARK: - 2. AttachThoughtToContext

struct AttachThoughtToContextIntent: AppIntent {
    static let title: LocalizedStringResource = "Attach Thought to Context"
    static let description = IntentDescription(
        "Capture a thought and bind it to whatever you're currently doing in Epistemos (active chat, open note, or running session)."
    )
    // W15 supportedModes — pure background capture; no UI needed.
    static let supportedModes: IntentModes = [.background]

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
        _ = try? await donate()
        return .result()
    }
}

// MARK: - 3. RecallActiveThesis

struct RecallActiveThesisIntent: AppIntent {
    static let title: LocalizedStringResource = "Recall Active Thesis"
    static let description = IntentDescription(
        "Read the current conversation's active thesis aloud (or display it). Surfaces what Epistemos thinks you're currently arguing for."
    )
    // W15 supportedModes — strictly background; the response is a
    // ProvidesDialog so Spotlight/Siri renders it inline.
    static let supportedModes: IntentModes = [.background]

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
        _ = try? await donate()
        return .result(dialog: IntentDialog(stringLiteral: state.activeThesis))
    }
}

// MARK: - 4. OpenRawThoughtSandbox

struct OpenRawThoughtSandboxIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Raw Thought Sandbox"
    static let description = IntentDescription(
        "Toggle Ambient Retrieval ON for the current conversation. The agent gains read-access to your quarantined raw thoughts; turn back off to return to deterministic mode."
    )
    // W15 supportedModes — toggle is silent background; only need
    // foreground escalation if the user wants to see the Sandbox UI
    // afterwards.
    static let supportedModes: IntentModes = [.background, .foreground(.dynamic)]

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
        _ = try? await donate()
        return .result(dialog: dialog)
    }
}

// MARK: - 5. DelegateToAgent

struct DelegateToAgentIntent: AppIntent {
    static let title: LocalizedStringResource = "Delegate to Agent"
    static let description = IntentDescription(
        "Open the agent inspector with a prompt pre-filled. The agent will pick up your structured context (active thesis, recent notes, current vault) automatically."
    )
    // W15 supportedModes — capture in background; foreground if the
    // agent has streaming UI to surface. Long-running agent dispatch
    // MUST hand off to a Task.detached or LiveActivityIntent within
    // the 30-second background quota per Wave 15 §"third research
    // drop additions" — the perform() body below is fire-and-forget
    // (just queues the prompt into QuarantineArchive); the actual
    // agent work happens when the chat surface picks it up.
    static let supportedModes: IntentModes = [.background, .foreground(.dynamic)]

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
        _ = try? await donate()
        return .result()
    }
}
