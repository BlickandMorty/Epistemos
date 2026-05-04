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

    /// Index of the currently-highlighted row in the inline command
    /// palette. -1 = none selected (Enter submits the draft directly).
    /// Cleared when the palette closes or the draft becomes empty.
    var selectedPaletteIndex: Int = -1

    /// Per-session runID used to anchor every AgentEvent emitted from
    /// this expert mode lifecycle. Created on `enter()`, cleared on
    /// `exit()`. Stable across submissions inside the same session so
    /// the Provenance Console can group them.
    private(set) var sessionRunID: String = ""

    /// Stable per-submission tool-call id used to bind the start /
    /// approval / completion events together in the ledger. Set by
    /// `HermesExpertModeRunner.recordSubmissionStart` and read by the
    /// follow-up record helpers.
    var lastSubmissionToolCallID: String = ""

    init() {}

    func enter() {
        guard !isActive else { return }
        isActive = true
        heroReady = false
        draft = ""
        transcript = []
        lastErrorMessage = nil
        selectedPaletteIndex = -1
        sessionRunID = "hermes-expert-\(UUID().uuidString)"
    }

    func exit() {
        isActive = false
        heroReady = false
        draft = ""
        transcript = []
        showingCommandPalette = false
        lastErrorMessage = nil
        dispatching = false
        selectedPaletteIndex = -1
        sessionRunID = ""
    }

    func append(_ entry: HermesExpertTranscriptEntry) {
        transcript.append(entry)
    }

    func updateDraft(_ text: String) {
        draft = text
        let wasShowing = showingCommandPalette
        showingCommandPalette = text.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("/")
        if !text.isEmpty { lastErrorMessage = nil }
        // Reset selection whenever the visible palette changes shape.
        if showingCommandPalette != wasShowing {
            selectedPaletteIndex = -1
        }
    }

    func clearDraft() {
        draft = ""
        showingCommandPalette = false
        selectedPaletteIndex = -1
    }

    /// Move the palette selection up or down, clamped to [-1, count-1].
    /// -1 represents "no selection" so Enter still submits the raw draft.
    func movePaletteSelection(by delta: Int, matchCount: Int) {
        guard showingCommandPalette, matchCount > 0 else {
            selectedPaletteIndex = -1
            return
        }
        let next = selectedPaletteIndex + delta
        if next < 0 {
            selectedPaletteIndex = matchCount - 1
        } else if next >= matchCount {
            selectedPaletteIndex = 0
        } else {
            selectedPaletteIndex = next
        }
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
