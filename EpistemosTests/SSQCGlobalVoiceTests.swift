import Testing
import Foundation

@testable import Epistemos

// SS-QC (owner 2026-06-20): a GLOBAL default voice that applies across EVERY TTS surface, set via a
// voice picker in Settings, plus an honest quality hint ("premium sounds basic" = no Premium voice
// is downloaded → System Settings → Spoken Content → Manage Voices). This guards the functional
// core (resolution + persistence) headless; the picker UI + audio are owner-verified (non-blocking).
@Suite("SS-QC — global default voice")
struct SSQCGlobalVoiceTests {

    @Test("effectiveVoiceIdentifier: explicit wins, else the global default, else nil (→ preferredVoice)")
    func effectiveVoiceResolution() {
        // An explicit per-call pick always wins.
        #expect(EpistemosSpeechSynthesizer.effectiveVoiceIdentifier(
            explicit: "com.apple.x", globalDefault: "com.apple.y") == "com.apple.x")
        // No explicit pick → the global default applies (the SS-QC behavior: pick once, used everywhere).
        #expect(EpistemosSpeechSynthesizer.effectiveVoiceIdentifier(
            explicit: nil, globalDefault: "com.apple.y") == "com.apple.y")
        // Neither → nil, so resolveVoice falls back to preferredVoice() (best installed).
        #expect(EpistemosSpeechSynthesizer.effectiveVoiceIdentifier(
            explicit: nil, globalDefault: nil) == nil)
    }

    @Test("the global default voice round-trips through a fresh UserDefaults (persisted, clearable)")
    func globalDefaultRoundTrip() throws {
        let suiteName = "ss-qc-voice-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        #expect(EpistemosSpeechSynthesizer.globalDefaultVoiceIdentifier(defaults: defaults) == nil)
        EpistemosSpeechSynthesizer.setGlobalDefaultVoiceIdentifier("com.apple.voice.test", defaults: defaults)
        #expect(EpistemosSpeechSynthesizer.globalDefaultVoiceIdentifier(defaults: defaults) == "com.apple.voice.test")
        EpistemosSpeechSynthesizer.setGlobalDefaultVoiceIdentifier(nil, defaults: defaults)
        #expect(EpistemosSpeechSynthesizer.globalDefaultVoiceIdentifier(defaults: defaults) == nil)
    }

    @Test("resolveVoice consults the global default + Settings mounts the picker with the honest hint")
    func wiring() throws {
        let synth = try loadMirroredSourceTextFile("Epistemos/Engine/EpistemosSpeechSynthesizer.swift")
        // resolveVoice uses the global default (not only the per-call identifier / preferredVoice).
        #expect(synth.contains("globalDefault: globalDefaultVoiceIdentifier()"))
        // The picker is mounted in Settings and persists the choice.
        let section = try loadMirroredSourceTextFile("Epistemos/Views/Settings/VoicePreferencesSection.swift")
        #expect(section.contains("ModelVoicePickerSection("))
        #expect(section.contains("EpistemosSpeechSynthesizer.setGlobalDefaultVoiceIdentifier(newValue)"))
        // The picker content surfaces the honest premium-download hint (so "sounds basic" is explained).
        let picker = try loadMirroredSourceTextFile("Epistemos/Views/Shared/ModelVoicePickerSection.swift")
        #expect(picker.contains("voiceQualityHint()"))
    }
}
