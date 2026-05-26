import Foundation
import AVFoundation
import Testing
@testable import Epistemos

@Suite("Voice Input Permissions")
struct VoiceInputPermissionTests {
    @Test("bundle plist includes speech and microphone permission prompts for voice transcription")
    func bundlePlistIncludesSpeechAndMicrophonePermissionPrompts() throws {
        let data = try loadMirroredSourceDataFile("Epistemos-Info.plist")
        let plist = try #require(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])

        #expect(plist["NSSpeechRecognitionUsageDescription"] != nil)
        #expect(plist["NSMicrophoneUsageDescription"] != nil)
    }

    @Test("no-backend transcription error mentions Apple Speech and fallback tools")
    func noBackendTranscriptionErrorMentionsAppleSpeechAndFallbackTools() {
        let description = AudioTranscriberError.noBackendAvailable.errorDescription

        #expect(description?.contains("Apple Speech") == true)
        #expect(description?.contains("mlx-whisper") == true)
        #expect(description?.contains("whisper.cpp") == true)
    }

    @Test("speech synthesizer clamps invalid rate and pitch before speaking")
    func speechSynthesizerClampsInvalidRateAndPitch() {
        #expect(EpistemosSpeechSynthesizer.clampedRate(.nan) == AVSpeechUtteranceDefaultSpeechRate)
        #expect(EpistemosSpeechSynthesizer.clampedRate(-1) == AVSpeechUtteranceMinimumSpeechRate)
        #expect(EpistemosSpeechSynthesizer.clampedRate(99) == AVSpeechUtteranceMaximumSpeechRate)
        #expect(EpistemosSpeechSynthesizer.clampedPitch(.nan) == 1.0)
        #expect(EpistemosSpeechSynthesizer.clampedPitch(0.1) == 0.5)
        #expect(EpistemosSpeechSynthesizer.clampedPitch(3.0) == 2.0)
    }

    @Test("Apple Speech URL recognition continuation is single-resume guarded")
    func appleSpeechRecognitionContinuationIsSingleResumeGuarded() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/KnowledgeFusion/DataIngestion/AudioTranscriber.swift")

        #expect(source.contains("SingleResumeGate"))
        #expect(source.contains("resumeGate.resume"))
    }

    @Test("shared voice input button uses stable recorder pipeline instead of live audio tap")
    func voiceInputButtonUsesStableRecorderPipeline() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Shared/VoiceInputButton.swift")

        #expect(source.contains("ComposerVoiceInputService.shared"))
        #expect(source.contains("service.toggle()"))
        #expect(!source.contains("EpistemosSpeechAnalyzer.shared.startLive()"))
    }
}
