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
//     • noteReadAloud          → ProseEditorView (auto-reads a long note on open; wired 2026-06-20
//                                 at the onAppear/onChange one-shot seam, default off)
//
//   REMOVED (2026-06-21, do-nothing with no clean/valuable seam — not shown as for-show controls):
//     • brainDumpHotkeyDictate (no dictation-start seam exists to gate)
//     • perModelVoicePersona   (superseded by the SS-QC global default voice; wiring needs
//                               SwiftData/ModelProfileManager access MessageBubble lacks)
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

    @Test("noteReadAloud now auto-reads a long note on open (wired, no longer do-nothing)")
    func noteReadAloudIsWired() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Views/Notes/ProseEditorView.swift")
        // Wired at the note-open one-shot seam (onAppear/onChange of page.id), gated on the toggle
        // (default .manual = off) + a long note, speaking the markdown-stripped body.
        #expect(src.contains("VoicePreferences.shared.noteReadAloud == .auto"))
        #expect(src.contains("maybeAutoReadAloudOnOpen(noteId:"))
    }

    @Test("the 2 do-nothing toggles are REMOVED from Settings (not shown as for-show controls)")
    func deadTogglesRemovedFromSettings() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Views/Settings/VoicePreferencesSection.swift")
        // No Settings row binds these dead toggles any more — a shown do-nothing toggle is fake.
        #expect(!src.contains("binding: $prefs.brainDumpHotkeyDictate"))
        #expect(!src.contains("binding: $prefs.perModelVoicePersona"))
        // The wired toggles' rows remain.
        #expect(src.contains("binding: $prefs.agentResponseTTS"))
        #expect(src.contains("binding: $prefs.noteReadAloud"))
        #expect(src.contains("binding: $prefs.dictationAutoStop"))
        #expect(src.contains("binding: $prefs.quickCaptureReadBack"))
    }
}
