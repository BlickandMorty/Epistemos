import Foundation
import Testing

@Suite("Plan 3 Meeting/STT codepack")
struct MeetingSTTCodepackPlan3Tests {
    @Test("codepack keeps meeting note on LiveVoiceInputService plus TextCapturePipeline")
    func codepackUsesCanonicalVoiceAndCaptureSeams() throws {
        let plan = try loadMirroredSourceTextFile("docs/research/PLAN_3_MEETING_STT_CODEPACK_2026_06_28.md")

        for required in [
            "LiveVoiceInputService",
            "EpistemosSpeechAnalyzer.shared.startLive",
            "VoiceInputButton` consumes `LiveVoiceInputService.shared",
            "TextCapturePipeline.runFromAudio",
            "CaptureSourceMetadata",
            "SDPage.frontMatter",
            "source = meeting_stt",
            "source_kind = audio_transcript",
            "stt_engine = apple_speechanalyzer"
        ] {
            #expect(plan.contains(required), "Missing required Meeting/STT plan string: \(required)")
        }
    }

    @Test("codepack preserves Plan 3 boundaries and MAS honesty")
    func codepackPreservesBoundaries() throws {
        let plan = try loadMirroredSourceTextFile("docs/research/PLAN_3_MEETING_STT_CODEPACK_2026_06_28.md")

        for forbiddenBoundary in [
            "Do not edit `Epistemos/Goose/*`",
            "Do not build Plan 2 editor features here",
            "No cloud STT",
            "do not reintroduce hidden HTML comments",
            "no cloud STT, Whisper, Python, subprocess, Chromium, or Kokoro path enters meeting capture"
        ] {
            #expect(plan.contains(forbiddenBoundary), "Missing Meeting/STT boundary: \(forbiddenBoundary)")
        }
    }
}
