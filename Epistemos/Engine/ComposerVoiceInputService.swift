import Foundation

@MainActor
@Observable
final class ComposerVoiceInputService {
    static let shared = ComposerVoiceInputService()

    enum State: Equatable {
        case idle
        case requestingPermission
        case recording(startedAt: Date)
        case transcribing
        case error(String)
    }

    private(set) var state: State = .idle
    private(set) var latestTranscript: String = ""

    var isRecording: Bool { false }
    var isBusy: Bool { false }

    func toggle() async {
        state = .error("Voice input has been removed from the native chat composer.")
    }

    func cancel() {
        state = .idle
    }

    func tearDown() {
        cancel()
        latestTranscript = ""
    }

    func consumeTranscript() -> String? {
        nil
    }
}
