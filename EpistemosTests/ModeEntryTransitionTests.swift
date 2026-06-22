import Testing
@testable import Epistemos

/// Owner §292-313: the act/work mode-entry transition's LOGIC core. Verifies the deterministic state machine
/// (backspace greeting → typewrite mode name → reveal) independently of the visual blur/ascii layer.
@Suite("Mode-entry transition — greeting backspace → typewrite mode name → reveal")
struct ModeEntryTransitionTests {
    @Test("default labels: act → \"act\", work → \"work\"")
    func defaultLabels() {
        #expect(WorkspaceModeKind.act.defaultLabel == "act")
        #expect(WorkspaceModeKind.work.defaultLabel == "work")
        #expect(ModeEntryTransition(greeting: "Hi", mode: .act).modeName == "act")
        #expect(ModeEntryTransition(greeting: "Hi", mode: .work).modeName == "work")
        // owner may override act's label.
        #expect(ModeEntryTransition(greeting: "Hi", mode: .act, modeName: "Epistemos chat").modeName == "Epistemos chat")
    }

    @Test("starts idle showing the full greeting; not complete")
    func startsIdle() {
        let t = ModeEntryTransition(greeting: "Hello", mode: .act)
        #expect(t.phase == .idle)
        #expect(t.displayText == "Hello")
        #expect(!t.isComplete)
    }

    @Test("advancing erases the greeting, then types the mode name, then reveals")
    func fullProgression() {
        var t = ModeEntryTransition(greeting: "Hi", mode: .act) // greeting=2 chars, mode name "act"=3
        var frames: [String] = [t.displayText]
        var guardCounter = 0
        while !t.isComplete && guardCounter < 50 {
            t = t.advanced()
            frames.append(t.displayText)
            guardCounter += 1
        }
        #expect(t.isComplete, "must terminate")
        #expect(t.displayText == "act", "ends on the full mode name")
        // greeting fully erased at some point…
        #expect(frames.contains(""), "the title passes through empty between greeting and mode name")
        // …and the mode name is typed up progressively.
        #expect(frames.contains("a"))
        #expect(frames.contains("ac"))
        // greeting shrinks (H kept) before vanishing.
        #expect(frames.contains("H"))
        // never shows a greeting/mode-name hybrid (each phase is pure).
        #expect(!frames.contains("Hiact"))
    }

    @Test("revealed is a fixed point (advancing further is idempotent)")
    func revealedIsFixedPoint() {
        var t = ModeEntryTransition(greeting: "x", mode: .work)
        for _ in 0..<20 { t = t.advanced() }
        #expect(t.isComplete)
        let after = t.advanced()
        #expect(after == t, "advancing a revealed transition changes nothing")
        #expect(after.displayText == "work")
    }

    @Test("an empty greeting still types the mode name to completion")
    func emptyGreeting() {
        var t = ModeEntryTransition(greeting: "", mode: .act)
        var guardCounter = 0
        while !t.isComplete && guardCounter < 20 { t = t.advanced(); guardCounter += 1 }
        #expect(t.isComplete)
        #expect(t.displayText == "act")
    }
}
