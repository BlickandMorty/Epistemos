import Testing
import Foundation

// SS-QC consumer-wiring audit (owner 2026-06-20 DONE-RE-AUDIT — re-verify "done" Settings are
// actually user-facing, not just green). VoicePreferences ships 6 Auto/Manual toggles. This audit
// found only TWO are wired to behavior; the other four are do-nothing toggles (the owner's "never
// ship a do-nothing toggle" rule).
//
//   WIRED (drive real behavior — LOCKED below so they can't regress to no-ops):
//     • dictationAutoStop      → LandingView + ChatInputBar (autoStopOnSilence)
//     • quickCaptureReadBack   → QuickCaptureView (gates the sentence read-back)
//     • agentResponseTTS       → ChatState.completeProcessing (auto-speaks the finalized response;
//                                 wired 2026-06-20 at the one-shot completion seam, default off)
//
//   NOT-YET-WIRED (Settings shows them + a rationale, but nothing reads them — a real gap):
//     • noteReadAloud          (auto-read long notes on open)
//     • brainDumpHotkeyDictate (auto-start dictation on the global hotkey)
//     • perModelVoicePersona   (use the model's bound voice for read-aloud)
//
// Wiring the four is owner-present: each is an audio / mic / launch-path behavior that can't be
// self-verified headless (e.g. a wrong one-shot for agentResponseTTS would auto-speak every
// message on launch/scroll), so they are NOT wired blind here. This guard locks the two REAL
// toggles against silent regression and records the gap so it isn't mistaken for done.
@Suite("SS-QC — voice-preference toggle wiring audit")
struct VoicePreferenceWiringAuditTests {

    @Test("dictationAutoStop actually drives auto-stop-on-silence (not a do-nothing toggle)")
    func dictationAutoStopIsWired() throws {
        let landing = try loadMirroredSourceTextFile("Epistemos/Views/Landing/LandingView.swift")
        let chat = try loadMirroredSourceTextFile("Epistemos/Views/Chat/ChatInputBar.swift")
        #expect(landing.contains("VoicePreferences.shared.dictationAutoStop == .auto"))
        #expect(chat.contains(".dictationAutoStop == .auto"))
    }

    @Test("quickCaptureReadBack actually gates the Quick Capture read-back (not a do-nothing toggle)")
    func quickCaptureReadBackIsWired() throws {
        let qc = try loadMirroredSourceTextFile("Epistemos/Views/Capture/QuickCaptureView.swift")
        #expect(qc.contains("VoicePreferences.shared.quickCaptureReadBack == .auto"))
    }

    @Test("agentResponseTTS now drives auto-speak on response completion (wired, no longer do-nothing)")
    func agentResponseTTSIsWired() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/State/ChatState.swift")
        // Wired at the one-shot finalize seam (completeProcessing), gated on the toggle (default
        // .manual = off), speaking the actual final assistant text.
        #expect(src.contains("VoicePreferences.shared.agentResponseTTS == .auto"))
        #expect(src.contains("EpistemosSpeechSynthesizer.shared.speak(answerText)"))
    }
}
