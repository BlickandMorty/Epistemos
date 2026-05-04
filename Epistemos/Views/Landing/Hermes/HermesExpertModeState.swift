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

    /// Monotonic counter bumped on every submit. The shimmering sigil
    /// watches this for one-shot burst rings — visual feedback that
    /// "your input landed."
    private(set) var submitCounter: Int = 0
    func bumpSubmitCounter() { submitCounter &+= 1 }

    /// Per-session command history — newest at the END. Up-arrow walks
    /// backward, down-arrow forward, mirroring shell readline. Bounded
    /// to keep memory cheap; older entries fall off the front.
    private(set) var history: [String] = []
    private static let historyLimit = 64

    /// Index into `history` for the up/down recall walk. -1 means the
    /// user is currently editing fresh draft text (not in recall mode).
    var historyCursor: Int = -1

    /// Snapshot of the draft at the moment the user pressed Up the
    /// first time, so Down past the newest entry restores it.
    var draftSnapshotBeforeRecall: String? = nil

    init() {}

    func recordHistory(_ command: String) {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if let last = history.last, last == trimmed { return }
        history.append(trimmed)
        if history.count > Self.historyLimit {
            history.removeFirst(history.count - Self.historyLimit)
        }
    }

    /// Walk history backward (older). Returns the recalled string, or
    /// nil if no movement happens. Snapshots the current draft on the
    /// FIRST step into recall so down-past-newest restores it.
    func recallPrev(currentDraft: String) -> String? {
        guard !history.isEmpty else { return nil }
        if historyCursor == -1 {
            draftSnapshotBeforeRecall = currentDraft
            historyCursor = history.count - 1
        } else if historyCursor > 0 {
            historyCursor -= 1
        } else {
            return nil
        }
        return history[historyCursor]
    }

    /// Walk history forward (newer). Past-newest restores the draft
    /// snapshot; another step does nothing.
    func recallNext() -> String? {
        guard historyCursor != -1 else { return nil }
        if historyCursor < history.count - 1 {
            historyCursor += 1
            return history[historyCursor]
        }
        // Past the newest — restore the snapshot, exit recall mode.
        let snapshot = draftSnapshotBeforeRecall ?? ""
        historyCursor = -1
        draftSnapshotBeforeRecall = nil
        return snapshot
    }

    func resetRecall() {
        historyCursor = -1
        draftSnapshotBeforeRecall = nil
    }

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
///
/// Two payload shapes:
/// - `text` (terse inline row, rendered as a monospace transcript line)
/// - `artifact` (rich card via the existing `ArtifactBlockView`
///    pipeline — collapse, copy, save-to-file affordances for free)
///
/// Doctrinal note (canonical: `docs/fusion/COGNITIVE_GENUI_DOCTRINE_2026_05_03.md`):
/// the artifact path is the schema-first GenUI seed. When the full
/// `GenUIDispatcher` lands (Phase G.2), this entry shape migrates to
/// carry a `GenUIPayload` instead and the runner stops switching on
/// command kind to choose the artifact mime — the dispatcher handles
/// it. Until then this is the cleanest local route through the
/// existing `Artifact` + `ArtifactBlockView` infrastructure.
struct HermesExpertTranscriptEntry: Identifiable, Equatable, Sendable {
    let id: UUID
    let kind: Kind
    let text: String
    let artifact: Artifact?
    let timestamp: Date

    /// Identity equality is sufficient for diffing. `Artifact` itself
    /// isn't `Equatable` (it carries an arbitrary `content: String`
    /// blob from cloud responses) and we don't want to pay deep
    /// comparison on every diff anyway — the UUID is unique per
    /// instance.
    static func == (lhs: HermesExpertTranscriptEntry, rhs: HermesExpertTranscriptEntry) -> Bool {
        lhs.id == rhs.id
    }

    enum Kind: String, Equatable, Sendable {
        case userInput          // what the user typed; rendered with `>` prefix
        case systemEcho         // parsed-command echo from the dispatcher
        case systemResponse     // structured result text
        case info               // ambient info (mode change, etc.)
        case error              // dispatch error or unknown command
        case artifact           // rich card via ArtifactBlockView
    }

    init(kind: Kind, text: String, artifact: Artifact? = nil, timestamp: Date = .now) {
        self.id = UUID()
        self.kind = kind
        self.text = text
        self.artifact = artifact
        self.timestamp = timestamp
    }

    /// Shorthand: build an artifact-bearing entry. Kind is forced to
    /// `.artifact`; text is the artifact title for accessibility +
    /// fallback if the renderer can't draw the card.
    static func artifact(_ artifact: Artifact) -> HermesExpertTranscriptEntry {
        .init(kind: .artifact, text: artifact.title, artifact: artifact)
    }
}
