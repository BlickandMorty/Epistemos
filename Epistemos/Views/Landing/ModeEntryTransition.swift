import SwiftUI

/// VISIBLE SURFACES (owner §292-313): the reusable LOGIC CORE of the act/work mode-entry transition — the
/// greeting "backspaces / moves up", then the mode name is "typewriter-written", then the UI reveals. Shared
/// by BOTH modes; the VISUAL layer differs (act = native Apple blur-reveal; work = ASCII/pixel typewriter),
/// but the title text progression is identical, so it lives here as a pure, deterministic, unit-testable model
/// (no Date()/Timer inside — the view ticks it). This is the foundation the SwiftUI animation sits on; the
/// blur/ascii styling + landing-flow integration are the owner-reviewed visual follow-on.
nonisolated enum WorkspaceModeKind: String, Sendable, Equatable, CaseIterable {
    case act
    case work
    /// New Swarm-backed regular Chat surface (the App-Store-shaped general chat).
    case chat

    /// Canonical typed label per owner §301/§305 (act → "act"; work → "work"). Owner may choose
    /// "Epistemos chat" for act — pass an explicit label to `ModeEntryTransition` to override.
    var defaultLabel: String {
        switch self {
        case .act: return "act"
        case .work: return "work"
        case .chat: return "chat"
        }
    }
}

/// The discrete phases of the mode-entry title animation.
nonisolated enum ModeEntryPhase: String, Sendable, Equatable {
    /// Resting: the greeting is fully shown.
    case idle
    /// The greeting is being erased character-by-character (it "backspaces").
    case backspacingGreeting
    /// The mode name is being typed character-by-character.
    case typingModeName
    /// Done: the mode name is fully shown and the mode UI is revealed.
    case revealed
}

/// Deterministic state of the mode-entry title transition. `advanced()` moves it one character/phase forward;
/// the view drives it on a timer. `displayText` is exactly what the title slot shows at this step.
nonisolated struct ModeEntryTransition: Sendable, Equatable {
    let greeting: String
    let mode: WorkspaceModeKind
    /// The label typed in (defaults to the mode's canonical label; override for "Epistemos chat").
    let modeName: String
    private(set) var phase: ModeEntryPhase
    /// Characters erased (backspacing) or typed (typing) so far within the current phase.
    private(set) var charProgress: Int

    init(greeting: String, mode: WorkspaceModeKind, modeName: String? = nil) {
        self.greeting = greeting
        self.mode = mode
        self.modeName = modeName ?? mode.defaultLabel
        self.phase = .idle
        self.charProgress = 0
    }

    /// True once the mode name is fully written and the reveal can proceed.
    var isComplete: Bool { phase == .revealed }

    /// The text the title currently shows: full greeting → shrinking greeting → growing mode name → full name.
    var displayText: String {
        switch phase {
        case .idle:
            return greeting
        case .backspacingGreeting:
            let kept = max(0, greeting.count - charProgress)
            return String(greeting.prefix(kept))
        case .typingModeName:
            return String(modeName.prefix(charProgress))
        case .revealed:
            return modeName
        }
    }

    /// Advance one tick. Idempotent at `.revealed`. Pure — no clock/state outside the returned value.
    func advanced() -> ModeEntryTransition {
        var next = self
        switch phase {
        case .idle:
            next.phase = .backspacingGreeting
            next.charProgress = 0
        case .backspacingGreeting:
            if charProgress >= greeting.count {
                next.phase = .typingModeName
                next.charProgress = 0
            } else {
                next.charProgress = charProgress + 1
            }
        case .typingModeName:
            if charProgress >= modeName.count {
                next.phase = .revealed
                next.charProgress = modeName.count
            } else {
                next.charProgress = charProgress + 1
            }
        case .revealed:
            break
        }
        return next
    }
}

/// Thin view that renders the mode-entry title, driving `ModeEntryTransition` on a timer. Mode-appropriate
/// styling per §304-313: act = native font + blur-reveal (`.motionReveal`); work = monospaced ASCII feel.
/// The model (above) is the unit-tested logic; this view is the visual surface the owner reviews live.
struct ModeEntryTitleView: View {
    let greeting: String
    let mode: WorkspaceModeKind
    var modeName: String?
    /// Per-character tick. ~45ms reads as a deliberate typewriter without dragging.
    var tickMilliseconds: UInt64 = 45
    /// Fired once the transition reaches `.revealed`, so the parent can reveal the mode UI.
    var onRevealed: (() -> Void)?

    @State private var transition: ModeEntryTransition

    init(
        greeting: String,
        mode: WorkspaceModeKind,
        modeName: String? = nil,
        tickMilliseconds: UInt64 = 45,
        onRevealed: (() -> Void)? = nil
    ) {
        self.greeting = greeting
        self.mode = mode
        self.modeName = modeName
        self.tickMilliseconds = tickMilliseconds
        self.onRevealed = onRevealed
        _transition = State(initialValue: ModeEntryTransition(greeting: greeting, mode: mode, modeName: modeName))
    }

    var body: some View {
        Text(transition.displayText)
            .font(mode == .work ? .title2.monospaced() : .title2.weight(.semibold))
            .modifier(ActBlurReveal(active: mode == .act && transition.isComplete))
            .task { await run() }
    }

    private func run() async {
        while !transition.isComplete {
            try? await Task.sleep(nanoseconds: tickMilliseconds * 1_000_000)
            if Task.isCancelled { return }
            transition = transition.advanced()
        }
        onRevealed?()
    }
}

/// act's native blur-reveal accent (kept local + trivial so the model file compiles standalone; the richer
/// `.motionReveal()` ontology is applied where the full title chrome lands).
private struct ActBlurReveal: ViewModifier {
    let active: Bool
    func body(content: Content) -> some View {
        content.blur(radius: active ? 0 : 2).opacity(active ? 1 : 0.85)
    }
}
