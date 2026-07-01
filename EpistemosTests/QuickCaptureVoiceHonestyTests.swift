import Testing
import Foundation

@testable import Epistemos

// Plan 3 owner update 2026-06-30: TTS is Kokoro-only. Quick Capture must not
// surface Apple voice selection or a premium-voice hint as the shipped fallback.
@Suite("Plan 3 — Kokoro-only TTS honesty on quick capture")
struct QuickCaptureVoiceHonestyTests {

    @Test("quick capture removes the Apple voice picker and uses the shared Kokoro gate")
    func quickCaptureShowsVoiceHint() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Views/Capture/QuickCaptureView.swift")
        #expect(!src.contains("EpistemosSpeechSynthesizer.voiceQualityHint().message"))
        #expect(!src.contains("voicesGroupedByTier(captureVoices)"))
        #expect(src.contains("EpistemosSpeechSynthesizer.isTextToSpeechAvailable()"))
    }

    @Test("shared TTS uses the Kokoro gate without AVSpeech fallback")
    func sharedTTSUsesKokoroGateWithoutAVSpeechFallback() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Engine/EpistemosSpeechSynthesizer.swift")
        #expect(src.contains("kokoroOnlyUnavailableMessage"))
        #expect(src.contains("KokoroCoreMLSynthesizer.renderRawText"))
        #expect(src.contains("Apple AVSpeech is not used as a fallback"))
        #expect(!src.contains("synthesizer.speak(utterance)"))
    }
}
