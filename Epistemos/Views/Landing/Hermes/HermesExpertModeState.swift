import Foundation
import Observation

/// Single source of truth for the Hermes Expert Mode landing surface.
/// Lifts state out of LandingView so the typewriter coordination, the
/// transcript, and the input ribbon can read/write the same store
/// without prop-drilling through the full landing view body.
///
/// Lifecycle:
/// - `enter()` flips `isActive` true and triggers the greeting morph
///   (LiquidGreeting reads this via the bound view's `searchMode`-style
///   binding).
/// - `exit()` clears the transcript draft, snaps `isActive` back to
///   false, and the landing view is responsible for re-asserting the
///   greeting playlist.
/// - `submit(_:)` records the entered command and notifies the runner
///   to dispatch. The dispatcher itself is wired in
///   `HermesExpertModeRunner` (Phase 2 — wired in a follow-up).
@MainActor
@Observable
final class HermesExpertModeState {

    /// Whether the expert mode surface is currently active. When true
    /// the landing view hides its normal greeting controls and shows
    /// the sigil + hero font + terminal box.
    var isActive: Bool = false

    /// The current draft text in the input ribbon. Bound to the
    /// terminal input field.
    var draft: String = ""

    /// Linear transcript of expert mode interactions. Append-only
    /// during a single session; cleared on `exit()`.
    var transcript: [HermesExpertTranscriptEntry] = []

    /// Whether the typewriter has finished printing "Hermes Agent" and
    /// the input ribbon is now ready to accept commands. The view
    /// flips this true when the hero typewriter completes.
    var heroReady: Bool = false

    /// Whether a dispatch is currently in flight. Disables the submit
    /// button and surfaces a subtle activity indicator.
    var dispatching: Bool = false

    /// Whether to show the inline command palette below the input.
    /// True when the draft starts with "/" and is filtering the
    /// capability registry.
    var showingCommandPalette: Bool = false

    /// Optional last-error string surfaced inline below the input.
    var lastErrorMessage: String? = nil

    init() {}

    func enter() {
        guard !isActive else { return }
        isActive = true
        heroReady = false
        draft = ""
        transcript = []
        lastErrorMessage = nil
    }

    func exit() {
        isActive = false
        heroReady = false
        draft = ""
        transcript = []
        showingCommandPalette = false
        lastErrorMessage = nil
        dispatching = false
    }

    func append(_ entry: HermesExpertTranscriptEntry) {
        transcript.append(entry)
    }

    func updateDraft(_ text: String) {
        draft = text
        showingCommandPalette = text.trimmingCharacters(in: .whitespaces).hasPrefix("/")
        if !text.isEmpty { lastErrorMessage = nil }
    }

    func clearDraft() {
        draft = ""
        showingCommandPalette = false
    }
}

/// One row in the expert mode transcript. Sum type so the renderer
/// can style each shape distinctly (user input gets a prompt prefix,
/// system output gets a softer treatment, errors get accent red).
struct HermesExpertTranscriptEntry: Identifiable, Equatable, Sendable {
    let id: UUID
    let kind: Kind
    let text: String
    let timestamp: Date

    enum Kind: String, Equatable, Sendable {
        case userInput          // what the user typed; rendered with `>` prefix
        case systemEcho         // parsed-command echo from the dispatcher
        case systemResponse     // structured result text
        case info               // ambient info (mode change, etc.)
        case error              // dispatch error or unknown command
    }

    init(kind: Kind, text: String, timestamp: Date = .now) {
        self.id = UUID()
        self.kind = kind
        self.text = text
        self.timestamp = timestamp
    }
}
