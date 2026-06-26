import Foundation

@MainActor
@Observable
final class AudioRecorder {
    private(set) var isRecording = false
    var isMicrophoneAuthorized: Bool { false }

    func requestPermission() async -> Bool {
        false
    }

    func startRecording() throws {
        throw NSError(
            domain: "Epistemos.AudioCapture",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Audio capture has been removed."]
        )
    }

    func stopRecording() -> URL? {
        isRecording = false
        return nil
    }
}

struct AudioTranscriber {
    func transcribe(audioURL: URL) async throws -> String {
        _ = audioURL
        throw NSError(
            domain: "Epistemos.AudioCapture",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "Audio transcription has been removed."]
        )
    }
}
