import Foundation
import Testing

@Suite("Plan 3 Meeting/STT codepack")
struct MeetingSTTCodepackPlan3Tests {
    @Test("codepack keeps meeting note on LiveVoiceInputService plus TextCapturePipeline")
    func codepackUsesCanonicalVoiceAndCaptureSeams() throws {
        let plan = try loadMirroredSourceTextFile("docs/research/PLAN_3_MEETING_STT_CODEPACK_2026_06_28.md")
        let view = try loadMirroredSourceTextFile("Epistemos/Views/Meeting/MeetingNoteView.swift")
        let buttons = try loadMirroredSourceTextFile("Epistemos/Views/Landing/LandingFeatureButtons.swift")

        for required in [
            "LiveVoiceInputService",
            "EpistemosSpeechAnalyzer.shared.startLive",
            "VoiceInputButton` consumes `LiveVoiceInputService.shared",
            "TextCapturePipeline.runFromAudio",
            "TextCapturePipeline.maxCleanedTextCharacters",
            "CaptureSourceMetadata",
            "SDPage.frontMatter",
            "source = meeting_stt",
            "source_kind = audio_transcript",
            "stt_engine = apple_speechanalyzer",
            "stale silence windows are guarded by capture generation"
        ] {
            #expect(plan.contains(required), "Missing required Meeting/STT plan string: \(required)")
        }
        for required in [
            "@Environment(UIState.self)",
            "ToolbarCapsuleButton(",
            "transcriptSurfaceBackground",
            "ui.theme.resolved.background.color",
            "ui.theme.resolved.foreground.color",
            "ui.theme.resolved.mutedForeground.color",
            ".lineLimit(1)",
            ".truncationMode(.tail)",
            ".frame(maxWidth: 220, alignment: .trailing)",
            "private var isSaved: Bool",
            "private var canSave: Bool",
            "Saved note: \\(title)",
            "VoiceCapturePresentationBounds.statusMessage(\"Saved note:",
            "service.tearDownCapture()",
            ".disabled(!canSave)",
            ".environment(UIState())",
        ] {
            #expect(view.contains(required), "Missing native Meeting/STT surface string: \(required)")
        }
        #expect(!view.contains("Divider()"))
        #expect(!view.contains("textBackgroundColor"))
        #expect(!view.contains(".foregroundStyle(.secondary)"))
        #expect(buttons.contains("MeetingNoteLandingGateStatus.status().isActive"))
        #expect(buttons.contains("AVCaptureDevice.authorizationStatus(for: .audio)"))
        #expect(buttons.contains("microphone access in System Settings"))
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

    @Test("codepack and rollup mark Meeting/STT shipped")
    func codepackAndRollupMarkMeetingSTTShipped() throws {
        let plan = try loadMirroredSourceTextFile("docs/research/PLAN_3_MEETING_STT_CODEPACK_2026_06_28.md")
        let capabilities = try loadMirroredSourceTextFile("docs/research/PLAN_3_CAPABILITIES_2026_06_28.md")

        #expect(plan.contains("shipped code"))
        #expect(plan.contains("## Shipped state"))
        #expect(plan.contains("## Delivered build"))
        #expect(plan.contains("## Delivery order"))
        #expect(capabilities.contains("Meeting/lecture note — SHIPPED (Pass 9)"))
        #expect(capabilities.contains("MeetingNoteCaptureService"))
        #expect(capabilities.contains("stt_engine=apple_speechanalyzer"))
        #expect(capabilities.contains("live transcript buffer is capped to the capture pipeline envelope"))
        #expect(capabilities.contains("capture-generation and silence-window token guards"))

        for stale in [
            "clone-ready",
            "[INFERRED]` tagged",
        ] where plan.contains(stale) {
            Issue.record("Meeting/STT codepack still contains stale phrase: \(stale)")
        }
        for stale in [
            "Apple Speech / local Whisper",
            "a note + AI summary",
            "MEDIUM effort",
        ] where capabilities.contains(stale) {
            Issue.record("Plan 3 capabilities still contains stale Meeting/STT phrase: \(stale)")
        }
    }
}
