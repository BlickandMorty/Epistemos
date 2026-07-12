import Testing
import Foundation

// SS-QC consumer-wiring audit (owner 2026-06-20 DONE-RE-AUDIT — re-verify "done" Settings are
// actually user-facing, not just green). VoicePreferences ships 6 Auto/Manual toggles. This audit
// found only a subset were wired to behavior; the rest were do-nothing toggles (the owner's "never
// ship a do-nothing toggle" rule).
//
//   WIRED (drive real behavior — LOCKED below so they can't regress to no-ops):
//     • dictationAutoStop      → MeetingNoteCaptureService (auto-stop after final silence)
//     • quickCaptureReadBack   → QuickCaptureView (gates the sentence read-back)
//     • noteReadAloud          → ProseEditorView (auto-reads a long note on open; wired 2026-06-20
//                                 at the onAppear/onChange one-shot seam, default off)
//
//   REMOVED (2026-06-21, do-nothing with no clean/valuable seam — not shown as for-show controls):
//     • brainDumpHotkeyDictate (no dictation-start seam exists to gate)
//     • agentResponseTTS       (no assistant-stream completion consumer exists yet)
//     • perModelVoicePersona   (superseded by the SS-QC global default voice)
//
// Wiring these is owner-present: each is an audio / mic / launch-path behavior that can't be
// self-verified headless. This guard locks the surviving REAL toggles against silent regression
// and records the removed toggles so they are not mistaken for done.
@Suite("SS-QC — voice-preference toggle wiring audit")
struct VoicePreferenceWiringAuditTests {

    @Test("dictationAutoStop actually drives auto-stop-on-silence (not a do-nothing toggle)")
    func dictationAutoStopIsWired() throws {
        let service = try loadMirroredSourceTextFile("Epistemos/Engine/MeetingNoteCaptureService.swift")
        #expect(service.contains("VoicePreferences.shared.dictationAutoStop == .auto"))
        #expect(service.contains("scheduleAutoStopAfterSilence()"))
        #expect(service.contains("autoStopIfStillSilent()"))
    }

    @Test("quickCaptureReadBack actually gates the Quick Capture read-back (not a do-nothing toggle)")
    func quickCaptureReadBackIsWired() throws {
        let qc = try loadMirroredSourceTextFile("Epistemos/Views/Capture/QuickCaptureView.swift")
        #expect(qc.contains("VoicePreferences.shared.quickCaptureReadBack == .auto"))
    }

    @Test("noteReadAloud now auto-reads a long note on open (wired, no longer do-nothing)")
    func noteReadAloudIsWired() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Views/Notes/ProseEditorView.swift")
        // Wired at the note-open one-shot seam (onAppear/onChange of page.id), gated on the toggle
        // (default .manual = off) + a long note, speaking the markdown-stripped body.
        #expect(src.contains("VoicePreferences.shared.noteReadAloud == .auto"))
        #expect(src.contains("maybeAutoReadAloudOnOpen(noteId:"))
        #expect(src.contains("EpistemosAgentReadAloud.speak("))
        #expect(src.contains("surface: .proseNoteBody"))
    }

    @Test("do-nothing toggles are REMOVED from Settings (not shown as for-show controls)")
    func deadTogglesRemovedFromSettings() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Views/Settings/VoicePreferencesSection.swift")
        // No Settings row binds these dead toggles any more — a shown do-nothing toggle is fake.
        #expect(!src.contains("binding: $prefs.agentResponseTTS"))
        #expect(!src.contains("Speak agent responses aloud"))
        #expect(!src.contains("binding: $prefs.brainDumpHotkeyDictate"))
        #expect(!src.contains("binding: $prefs.perModelVoicePersona"))
        // The surviving wired toggles' rows remain.
        #expect(src.contains("binding: $prefs.noteReadAloud"))
        #expect(src.contains("binding: $prefs.dictationAutoStop"))
        #expect(src.contains("binding: $prefs.quickCaptureReadBack"))
    }
}
