import Testing
import Foundation

@testable import Epistemos

// SS-QC (D) (owner 2026-06-20): manual TTS read-back in Quick Capture. The owner asked to "add the
// model text-to-speech... read back to you automatically or manually." This slice adds the MANUAL
// control (the canonical doc's recommended first step — small, self-contained, no TK2/routing
// touch), reusing the shipped ReadAloudButton + EpistemosSpeechSynthesizer. Honest: "model voice"
// today is an AVSpeech persona, not neural TTS (cross-ref SS-Q). Auto-on-type is the follow-on.
@Suite("SS-QC quick-capture TTS read-back (manual)")
struct SSQCQuickCaptureReadBackTests {

    // The manual read-back button is wired into the capture action bar, bound to the live
    // capture text, and reuses the shared synth (no new TTS engine).
    @Test("the capture action bar mounts a ReadAloudButton bound to the live captureText")
    func readAloudButtonWired() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Views/Capture/QuickCaptureView.swift")
        #expect(src.contains("ReadAloudButton(text: captureText"))
        #expect(src.contains("Read the captured text aloud"))
    }

    // ReadAloudButton disables itself on empty/whitespace text — so wiring it to a possibly-empty
    // capture buffer never speaks a blank string.
    @Test("ReadAloudButton guards empty text (no blank read-back)")
    func readAloudGuardsEmpty() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Views/Shared/ReadAloudButton.swift")
        #expect(src.contains("text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty"))
    }
}
