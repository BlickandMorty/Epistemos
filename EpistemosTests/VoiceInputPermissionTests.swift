import Foundation
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
}
