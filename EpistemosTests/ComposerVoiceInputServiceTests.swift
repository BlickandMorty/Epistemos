import Foundation
import Testing
@testable import Epistemos

@Suite("Composer Voice Input Service")
@MainActor
struct ComposerVoiceInputServiceTests {
    @Test("successful transcription deletes composer temp audio")
    func successfulTranscriptionDeletesComposerTempAudio() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let service = makeService(tempDirectory: directory) { url in
            #expect(FileManager.default.fileExists(atPath: url.path))
            return Self.makeTranscript(sourceURL: url, text: "hello from composer voice")
        }

        await service.toggle()
        let recordingURL = try #require(try onlyComposerRecording(in: directory))

        await service.toggle()

        #expect(!FileManager.default.fileExists(atPath: recordingURL.path))
        #expect(service.consumeTranscript() == "hello from composer voice")
    }

    @Test("transcription error deletes composer temp audio")
    func transcriptionErrorDeletesComposerTempAudio() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let service = makeService(tempDirectory: directory) { _ in
            throw StubTranscriptionError.failure
        }

        await service.toggle()
        let recordingURL = try #require(try onlyComposerRecording(in: directory))

        await service.toggle()

        #expect(!FileManager.default.fileExists(atPath: recordingURL.path))
        if case .error(let message) = service.state {
            #expect(message.contains("Transcription failed"))
        } else {
            Issue.record("Expected transcription failure state")
        }
    }

    @Test("cancel deletes composer temp audio")
    func cancelDeletesComposerTempAudio() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let service = makeService(tempDirectory: directory) { url in
            Self.makeTranscript(sourceURL: url, text: "unused")
        }

        await service.toggle()
        let recordingURL = try #require(try onlyComposerRecording(in: directory))

        service.cancel()

        #expect(!FileManager.default.fileExists(atPath: recordingURL.path))
        #expect(service.state == .idle)
    }

    @Test("teardown deletes composer temp audio")
    func teardownDeletesComposerTempAudio() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let service = makeService(tempDirectory: directory) { url in
            Self.makeTranscript(sourceURL: url, text: "unused")
        }

        await service.toggle()
        let recordingURL = try #require(try onlyComposerRecording(in: directory))

        service.tearDown()

        #expect(!FileManager.default.fileExists(atPath: recordingURL.path))
        #expect(service.state == .idle)
    }

    @Test("composer mic view tears down recording on disappear")
    func composerMicViewTearsDownRecordingOnDisappear() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Chat/ComposerMicButton.swift")

        #expect(source.contains(".onDisappear"))
        #expect(source.contains("service.tearDown()"))
    }

    private func makeService(
        tempDirectory: URL,
        transcribe: @escaping @Sendable (URL) async throws -> TranscribedAudio
    ) -> ComposerVoiceInputService {
        ComposerVoiceInputService(
            tempDirectory: tempDirectory,
            permissionProvider: { true },
            recorderFactory: { url, _ in StubRecorder(url: url) },
            transcribeAudio: transcribe
        )
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("composer-voice-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func onlyComposerRecording(in directory: URL) throws -> URL? {
        let files = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )
            .filter { $0.lastPathComponent.hasPrefix("composer-") && $0.pathExtension == "m4a" }
        #expect(files.count <= 1)
        return files.first
    }

    private nonisolated static func makeTranscript(sourceURL: URL, text: String) -> TranscribedAudio {
        TranscribedAudio(
            id: UUID(),
            sourceURL: sourceURL,
            fullText: text,
            segments: [
                AudioSegment(startTime: 0, endTime: 1, text: text, speaker: nil),
            ],
            wordsPerMinute: 120,
            hesitationFrequency: 0,
            speakerCount: text.isEmpty ? 0 : 1
        )
    }
}

private final class StubRecorder: ComposerVoiceAudioRecording {
    private let url: URL

    init(url: URL) {
        self.url = url
    }

    func prepareToRecord() -> Bool {
        true
    }

    func record() -> Bool {
        FileManager.default.createFile(atPath: url.path, contents: Data("voice".utf8))
    }

    func stop() {}
}

private enum StubTranscriptionError: Error {
    case failure
}
