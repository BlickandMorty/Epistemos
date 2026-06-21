import Testing
import Foundation

@testable import Epistemos

// L4413 — owner ("tried the premium Apple-native voices" on quick capture, but none was downloaded;
// OS-managed). The point-of-use voice picker already exists; this pins that it also surfaces the
// HONEST availability hint, so a user who has no Premium/Enhanced voice installed is told exactly how
// to get one (System Settings → Spoken Content → Manage Voices) instead of hitting a silent dead end.
// The hint reads live AVSpeechSynthesisVoice state, so this source-guards the wiring + the actionable
// guidance (which can't be unit-driven without controlling the OS voice catalogue).
@Suite("L4413 — voice premium-honesty on quick capture")
struct QuickCaptureVoiceHonestyTests {

    @Test("the quick-capture voice picker surfaces the honest availability hint")
    func quickCaptureShowsVoiceHint() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Views/Capture/QuickCaptureView.swift")
        #expect(src.contains("EpistemosSpeechSynthesizer.voiceQualityHint().message"))
    }

    @Test("every non-premium hint is actionable — points to System Settings, never a dead end")
    func hintIsActionable() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Engine/EpistemosSpeechSynthesizer.swift")
        // The default + enhanced branches (the owner's "no premium downloaded" case) must route the
        // user to where macOS actually manages voice downloads.
        #expect(src.contains("System Settings → Spoken Content → Manage Voices"))
        #expect(src.contains("download an Enhanced or Premium voice"))
    }
}
