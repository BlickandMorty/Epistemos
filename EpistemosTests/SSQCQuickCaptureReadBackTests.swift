import Testing
import Foundation

@testable import Epistemos

// SS-QC (D) (owner 2026-06-20): manual TTS read-back in Quick Capture.
// Plan 3 owner update 2026-06-30: the button stays mounted, but playback is
// Kokoro-only and gated by native package/runtime readiness.
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

    // The PURE core of auto-on-type read-back: extract the just-finished sentence, never a fragment.
    @Test("lastCompletedSentence returns the just-finished sentence, nil for a fragment")
    func lastCompletedSentenceExtraction() {
        // No terminator yet → nothing to read (never speaks a half-typed fragment).
        #expect(QuickCaptureReadBack.lastCompletedSentence(in: "this is half a thou") == nil)
        // Multi-sentence → the LAST completed one, trimmed.
        #expect(QuickCaptureReadBack.lastCompletedSentence(in: "Hello world. This is a test.") == "This is a test.")
        // A trailing fragment after the last terminator is excluded.
        #expect(QuickCaptureReadBack.lastCompletedSentence(in: "Done. Now typing more") == "Done.")
        // Single sentence, whitespace-trimmed.
        #expect(QuickCaptureReadBack.lastCompletedSentence(in: "  Just one!  ") == "Just one!")
        // Mixed terminators.
        #expect(QuickCaptureReadBack.lastCompletedSentence(in: "A. Really?") == "Really?")
        // Empty.
        #expect(QuickCaptureReadBack.lastCompletedSentence(in: "") == nil)
    }

    // Auto read-back is OPT-IN (default manual) in BOTH the seed + the accessor — never surprises.
    @Test("quickCaptureReadBack is opt-in: init seed + accessor default to manual")
    func autoReadBackDefaultsManual() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Engine/VoicePreferences.swift")
        #expect(src.contains("decode(forKey: VoicePreferenceKeys.quickCaptureReadBack, default: .manual)"))
        #expect(src.contains("d.set(VoiceDecisionMode.manual.rawValue, forKey: VoicePreferenceKeys.quickCaptureReadBack)"))
    }

    // The view debounces + dedups + gates on the pref and the Kokoro-only TTS gate,
    // and stops any transient speech state on close.
    @Test("QuickCaptureView wires debounced, deduped auto read-back gated on the pref")
    func autoReadBackWired() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Views/Capture/QuickCaptureView.swift")
        #expect(src.contains("VoicePreferences.shared.quickCaptureReadBack == .auto"))
        #expect(src.contains("EpistemosSpeechSynthesizer.isTextToSpeechAvailable()"))
        #expect(src.contains("Task.sleep(for: .milliseconds(750))"))
        #expect(src.contains("sentence != lastSpokenSentence"))
        #expect(src.contains("EpistemosSpeechSynthesizer.shared.stop()"))
    }
}
