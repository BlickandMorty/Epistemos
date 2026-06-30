import Foundation
import SwiftData

@main
enum MeetingSTTSmoke {
    static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data("meeting-STT smoke failed: \(message)\n".utf8))
        exit(1)
    }

    @MainActor
    static func main() async {
        TextCapturePipeline.calls = []

        let container: ModelContainer
        do {
            container = try ModelContainer(
                for: MeetingSTTSmokeModel.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        } catch {
            fail("could not create SwiftData smoke container: \(error)")
        }
        let context = ModelContext(container)

        let voice = LiveVoiceInputService()
        var currentDate = Date(timeIntervalSince1970: 0)
        let service = MeetingNoteCaptureService(
            voiceInput: voice,
            now: { currentDate },
            isAutoStopOnSilenceEnabled: { false }
        )

        await service.start()
        voice.finalTranscripts = ["Launch review", "Launch review\n\nSend recap to team"]
        voice.partialTranscript = "Open question"
        service.refreshFromVoiceInput()
        currentDate = Date(timeIntervalSince1970: 61)

        let result: CaptureResult
        do {
            result = try await service.finalize(modelContext: context)
        } catch {
            fail("finalize failed: \(error)")
        }

        guard result.createdNoteID == "meeting-smoke-page" else {
            fail("unexpected created note id")
        }
        guard TextCapturePipeline.calls.count == 1 else {
            fail("expected one runFromAudio call, got \(TextCapturePipeline.calls.count)")
        }
        let call = TextCapturePipeline.calls[0]
        guard call.transcription == "Launch review\n\nSend recap to team\n\nOpen question" else {
            fail("unexpected transcription: \(call.transcription)")
        }
        guard let metadata = call.sourceMetadata,
              metadata.source == "meeting_stt",
              metadata.sourceKind == "audio_transcript",
              metadata.durationSeconds == 61,
              metadata.sttEngine == "apple_speechanalyzer",
              metadata.audioSource == nil
        else {
            fail("meeting metadata was not threaded into runFromAudio")
        }
        guard case .saved(let pageID, let title) = service.state,
              pageID == "meeting-smoke-page",
              title == "Launch review"
        else {
            fail("service did not enter saved state: \(service.state)")
        }

        print("meeting-STT smoke OK: runFromAudio=true metadata=meeting_stt duration=61 saved=true")
    }
}
